CREATE PROCEDURE `teamu-542ac`.update_user_post_data()
BEGIN
  --combine owner and team members in collab data to a single array
  UPDATE `teamu-542ac`.collab_dataset.collabs
  SET team_uids = ARRAY_CONCAT([owner_uid], team_uids);

  --add collab titles to data of each user
  UPDATE `teamu-542ac`.user_dataset.users u
  SET u.project_titles = (
    SELECT ARRAY_AGG(c.title)
    FROM `teamu-542ac`.collab_dataset.collabs c
    WHERE u.uid IN UNNEST(c.team_uids)
  );

  --aggregate post comments to column of each post
  UPDATE `teamu-542ac`.post_dataset.posts p
  SET p.comments = (
    SELECT ARRAY_AGG(pc.content)
    FROM `teamu-542ac`.post_dataset.posts_comments pc
    WHERE pc.po_id = p.po_id
  );

  --create numerical features for posts dataset
  UPDATE `teamu-542ac`.post_dataset.posts
  SET post_length = LENGTH(description),
      vote_count = ARRAY_LENGTH(votes),
      upvote_count = upvotes - downvotes,
      view_count = ARRAY_LENGTH(views),
      comment_count = ARRAY_LENGTH(comments),
      avg_time_viewed = (SELECT IF(ARRAY_LENGTH(view_lengths) > 0, 
                                  SUM(v) / ARRAY_LENGTH(view_lengths), 
                                  0) 
                        FROM UNNEST(view_lengths) AS v);

  --create numerical features for users dataset
  UPDATE `teamu-542ac`.user_dataset.users u
  SET 
    u.viewed_posts = (
      SELECT COUNT(post_id) 
      FROM `teamu-542ac`.interaction_dataset.user_post_interactions
      WHERE user_id = u.uid AND interaction_type = 'view'
    ),
    u.upvoted_posts = (
      SELECT COUNT(post_id) 
      FROM `teamu-542ac`.interaction_dataset.user_post_interactions
      WHERE user_id = u.uid AND interaction_type = 'upvote'
    ),
    u.commented_posts = (
      SELECT COUNT(post_id) 
      FROM `teamu-542ac`.interaction_dataset.user_post_interactions
      WHERE user_id = u.uid AND interaction_type = 'comment'
    );
END;

--create numerical features for posts dataset
UPDATE `teamu-542ac`.post_dataset.posts
SET 
  post_length = LENGTH(description),
  vote_count = ARRAY_LENGTH(votes),
  upvote_count = upvotes - downvotes,
  view_count = ARRAY_LENGTH(views),
  comment_count = ARRAY_LENGTH(comments),
  avg_time_viewed = (
    SELECT IF(ARRAY_LENGTH(view_lengths) > 0, 
              SUM(v) / ARRAY_LENGTH(view_lengths), 
              0)
    FROM UNNEST(view_lengths) AS v
  )

--create weight for each interaction
UPDATE `teamu-542ac`.interaction_dataset.user_post_interactions
SET weight = CASE
  WHEN interaction_type = 'upvote' THEN 2.0
  WHEN interaction_type = 'comment' THEN 1.5
  WHEN interaction_type = 'view' THEN 1.0
  ELSE 0.0  -- For negative samples or unrecognized types
END

--find posts that were fed, but not interacted with for negative sampling
WITH fed_posts AS (
  SELECT
    u.uid AS user_id,
    post_id
  FROM
    `teamu-542ac`.user_dataset.users u,
    UNNEST(u.fed) AS post_id  -- Unnest to get each fed post
),
uninteracted_posts AS (
  SELECT
    f.user_id,
    f.post_id
  FROM
    fed_posts f
  LEFT JOIN
    `teamu-542ac`.interaction_dataset.user_post_interactions i
  ON
    f.user_id = i.user_id AND f.post_id = i.post_id
  WHERE
    i.post_id IS NULL  -- Find fed posts without interactions
)

--insert non-interactions as interactions of type no_interaction and weight as 0
INSERT INTO `teamu-542ac`.interaction_dataset.user_post_interactions (user_id, post_id, interaction_type, weight)
SELECT
  user_id,
  post_id,
  'no_interaction' AS interaction_type,
  0.0 AS weight
FROM
  uninteracted_posts

--calculate click through rate
UPDATE `teamu-542ac`.post_dataset.posts p
SET ctr = (
  SELECT SAFE_DIVIDE(
    (SELECT COUNT(DISTINCT user_id)
     FROM `teamu-542ac`.user_dataset.users
     WHERE ARRAY_CONTAINS(p.po_id, fed)),
    
    (SELECT COUNT(DISTINCT u.uid)
     FROM `teamu-542ac`.interaction_dataset.user_post_interactions u
     WHERE u.po_id = p.po_id AND u.interaction_type = 'view')
  )
)

--calculate login frequency for each user
WITH login_intervals AS (
  SELECT
    uid,
    TIMESTAMP_DIFF(login_times[OFFSET(i+1)], login_times[OFFSET(i)], SECOND) AS interval
  FROM `teamu-542ac`.user_dataset.users,
  UNNEST(GENERATE_ARRAY(0, ARRAY_LENGTH(login_times) - 2)) AS i
),
ema_intervals AS (
  SELECT
    uid,
    EXP(SUM(LN(interval)) / COUNT(interval)) AS ema_interval
  FROM login_intervals
  GROUP BY uid
)
UPDATE `teamu-542ac`.user_dataset.users u
SET login_frequency = COALESCE(ema_intervals.ema_interval, 0)
FROM ema_intervals
WHERE u.uid = ema_intervals.uid

--calculate recently interacted post titles for each user
UPDATE `teamu-542ac`.user_dataset.users u
SET recent_titles = (
  SELECT ARRAY_AGG(p.title ORDER BY i.interaction_time DESC LIMIT 10)
  FROM `teamu-542ac`.user_dataset.user_post_interactions i
  JOIN `teamu-542ac`.user_dataset.posts p ON i.post_id = p.po_id
  WHERE i.user_id = u.uid
)







