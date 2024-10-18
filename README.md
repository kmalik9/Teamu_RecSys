
# Teamu Recommendation System - Two-Tower Architecture

## 1. Overview
This repository contains the design and implementation of the **Teamu Recommender System**, focusing on a **Two-Tower architecture**. The system generates embeddings for both users and posts, leveraging deep learning to match them through similarity. It is designed for scalability and personalization while incorporating user profiles and content interactions to generate relevant recommendations.

## 2. System Objectives

- **Maximize personalized content delivery**: Provide tailored recommendations to users based on their interactions and preferences.
- **Generate AI-driven post ideas for user teams**: These embeddings are also leveraged by LLMs to AI-generate high-ranking content for Teamu.
- **Leverage AI for deep learning recommendations**: Match user and post embeddings for optimal content relevance.
- **Ensure the system can scale effectively**: Handle new users/posts efficiently, even with cold-start scenarios.

## 3. Tools and Technologies

- **Languages**: Python, SQL, Dart (for Flutter frontend).
- **Libraries**: TensorFlow, TF Recommenders, Pandas, Sci-Kit.
- **Databases**: Supabase (PostgreSQL with pgvector for vector embeddings).
- **Cloud Services**: Vertex AI (for training and deployment), Supabase Edge Functions.
- **Tracking and Analytics**: Mixpanel (for event tracking).

## 4. User and Content Features

### User Features
- **Content Data**: Passions, Location, Project Titles, Created Posts, Bio.
- **Behavioral Data**: Viewed, Upvoted, and Commented Posts.
- **Embeddings**: Generated and stored in the `user_embeddings` table.

### Post Features
- **Content Data**: Post ID, Title, Description, Post Length, Comments, Global/Local, User Location (if local).
- **Embeddings**: Stored in the `post_embeddings` table, generated from title, description, and comments.
- **Interaction Features**: Logs every user's interaction with posts (views, likes, comments, votes).

## 5. Database Schema

```sql
CREATE TABLE user_features (
   user_id SERIAL PRIMARY KEY,
   passions TEXT[],
   location GEOGRAPHY,
   bio TEXT,
   embedding VECTOR(512),
   created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE post_features (
   post_id SERIAL PRIMARY KEY,
   user_id INTEGER REFERENCES users(user_id),
   title TEXT,
   description TEXT,
   post_length INTEGER,
   comments TEXT[],
   vote_count INTEGER DEFAULT 0,
   view_count INTEGER DEFAULT 0,
   avg_time_viewed INTERVAL,
   location GEOGRAPHY,
   embedding VECTOR(512),
   created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## 6. Model Architecture

### 6.1 User Tower
This model generates embeddings for users based on their profile and interaction data. It includes:

- **Categorical features**: Passions, Location.
- **Behavioral features**: Count of liked, commented, and viewed posts.
- **Final Dense Layer**: Produces the user embedding vector.

```python
class UserTower(nn.Module):
    def __init__(self, num_users, embed_dim):
        super(UserTower, self).__init__()
        self.user_embedding = nn.Embedding(num_users, embed_dim)
        self.fc = nn.Linear(embed_dim, embed_dim)
    def forward(self, user_id):
        user_embed = self.user_embedding(user_id)
        return self.fc(user_embed)
```

### 6.2 Post Tower
Generates embeddings for posts based on their content features, including title, description, and interaction data.

```python
class PostTower(nn.Module):
    def __init__(self, num_posts, embed_dim):
        super(PostTower, self).__init__()
        self.post_embedding = nn.Embedding(num_posts, embed_dim)
        self.fc = nn.Linear(embed_dim, embed_dim)
    def forward(self, post_id):
        post_embed = self.post_embedding(post_id)
        return self.fc(post_embed)
```

### 6.3 Similarity Matching
Embeddings from both towers are compared using dot product similarity.

```python
def get_similarity(user_embedding, post_embedding):
    return torch.dot(user_embedding, post_embedding)
```

## 7. Recommendation Algorithm

1. **User and Post Embedding Retrieval**: Fetch embeddings from the database.
2. **Ranking**: Rank posts based on similarity to the user's embedding.
3. **Real-Time Personalization**: Continuously update user embeddings based on interactions.

## 8. Evaluation Metrics

- **Precision/Recall**: Measure how accurately recommendations match user preferences.
- **Click-Through Rate (CTR)**: Percentage of recommended posts clicked by users.
- **Diversity**: Ensure varied content is shown.
- **Cold Start Performance**: Test the model's handling of new users and posts.

## 9. Deployment

- **Model Deployment**: Use Vertex AI for serving models in production.
- **Embedding Storage**: Store embeddings in Supabase's pgvector table.
- **Real-Time Updates**: Utilize Supabase Edge Functions for real-time embedding updates.

## 10. Installation and Setup

### Required Libraries

```bash
pip install tensorflow-recommenders tensorflow supabase pandas sklearn h3
```

### Data Preparation and Processing
Load, normalize, and process features from Supabase, including text and location-based features.

```python
user_data = supabase.table("user_features").select("*").execute()
posts_df = supabase.table("post_features").select("*").execute()
```

## 11. Training and Recommendations

### Model Training
Compile and train the model using user-post interactions.

```python
model.compile(optimizer=tf.keras.optimizers.Adam(learning_rate=0.001))
model.fit(cached_train, epochs=3)
```

### Generate Recommendations
Index and serve recommendations for users in real-time.

```python
_, post_ids = index(tf.constant([user_id]))
```

---
