CREATE TABLE `custom_recipes` (
	`user_id` text NOT NULL,
	`recipe_id` text NOT NULL,
	`recipe_json` text NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`user_id`, `recipe_id`)
);
--> statement-breakpoint
CREATE TABLE `environments` (
	`user_id` text NOT NULL,
	`recipe_id` text NOT NULL,
	`pinned_version` text,
	`custom_path` text,
	`enabled` integer DEFAULT true NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`user_id`, `recipe_id`)
);
--> statement-breakpoint
CREATE TABLE `users` (
	`id` text PRIMARY KEY NOT NULL,
	`login` text NOT NULL,
	`created_at` integer NOT NULL
);
