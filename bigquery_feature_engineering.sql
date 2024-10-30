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

UPDATE `teamu-542ac`.user_dataset.users u
SET 
  u.viewed_posts = COALESCE((
    SELECT COUNT(post_id)
    FROM `teamu-542ac`.interaction_dataset.user_post_interactions
    WHERE user_id = u.uid AND interaction_type = 'view'
  ), 0),
  
  u.upvoted_posts = COALESCE((
    SELECT COUNT(post_id)
    FROM `teamu-542ac`.interaction_dataset.user_post_interactions
    WHERE user_id = u.uid AND interaction_type = 'upvote'
  ), 0),
  
  u.commented_posts = COALESCE((
    SELECT COUNT(post_id)
    FROM `teamu-542ac`.interaction_dataset.user_post_interactions
    WHERE user_id = u.uid AND interaction_type = 'comment'
  ), 0)

UPDATE `teamu-542ac`.interaction_dataset.user_post_interactions
SET weight = CASE
  WHEN interaction_type = 'upvote' THEN 2.0
  WHEN interaction_type = 'comment' THEN 1.5
  WHEN interaction_type = 'view' THEN 1.0
  ELSE 0.0  -- For negative samples or unrecognized types
END




