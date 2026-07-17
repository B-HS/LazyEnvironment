CREATE TABLE `lazyenv_custom_recipes` (
	`user_id` text NOT NULL,
	`recipe_id` text NOT NULL,
	`recipe_json` text NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`user_id`, `recipe_id`)
);
--> statement-breakpoint
CREATE TABLE `lazyenv_environments` (
	`user_id` text NOT NULL,
	`recipe_id` text NOT NULL,
	`pinned_version` text,
	`custom_path` text,
	`enabled` integer DEFAULT true NOT NULL,
	`updated_at` integer NOT NULL,
	PRIMARY KEY(`user_id`, `recipe_id`)
);
--> statement-breakpoint
CREATE TABLE `lazyenv_users` (
	`id` text PRIMARY KEY NOT NULL,
	`login` text NOT NULL,
	`created_at` integer NOT NULL
);
