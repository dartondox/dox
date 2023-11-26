-- up
CREATE TABLE IF NOT EXISTS category (
    id serial PRIMARY KEY,
	name VARCHAR ( 255 ) UNIQUE NOT NULL,
	deleted_at TIMESTAMP,
	created_at TIMESTAMP,
	updated_at TIMESTAMP
)


-- down
DROP TABLE IF EXISTS category