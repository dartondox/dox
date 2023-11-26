-- up
CREATE TABLE IF NOT EXISTS blog (
    id serial PRIMARY KEY,
	user_id int NOT NULL,
	title VARCHAR ( 255 ) NOT NULL,
	slug VARCHAR ( 255 ) NOT NULL,
	description TEXT,
	deleted_at TIMESTAMP,
    created_at TIMESTAMP,
    updated_at TIMESTAMP 
)

-- down
DROP TABLE IF EXISTS blog 

