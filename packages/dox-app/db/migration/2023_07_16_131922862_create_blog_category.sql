-- up
CREATE TABLE IF NOT EXISTS blog_category (
    id serial PRIMARY KEY,
	blog_id BIGINT NOT NULL,
	category_id BIGINT NOT NULL
)

-- down
DROP TABLE IF EXISTS blog_category 
