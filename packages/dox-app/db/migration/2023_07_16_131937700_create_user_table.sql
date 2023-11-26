-- up
CREATE TABLE IF NOT EXISTS users (
    id serial PRIMARY KEY,
	name VARCHAR ( 255 ) NOT NULL,
	email VARCHAR ( 255 ) NOT NULL,
	password VARCHAR ( 255 ) NOT NULL,
	deleted_at TIMESTAMP,
    created_at TIMESTAMP,
    updated_at TIMESTAMP 
)

-- down
DROP TABLE IF EXISTS users 
