-- create database apploach;

create table if not exists `nobj` (
  `app_id` bigint unsigned not null,
  `nobj_id` bigint unsigned not null,
  `nobj_key` varbinary(4095) not null,
  `nobj_key_sha` binary(40) not null,
  `timestamp` double not null,
  primary key (`nobj_id`),
  key (`app_id`, `nobj_key_sha`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;

create table if not exists `log` (
  `app_id` bigint unsigned not null,
  `log_id` bigint unsigned not null,
  `target_nobj_id` bigint unsigned not null,
  `verb_nobj_id` bigint unsigned not null,
  `operator_nobj_id` bigint unsigned not null,
  `data` mediumblob not null,
  `timestamp` double not null,
  primary key (`log_id`),
  key (`app_id`, `target_nobj_id`, `timestamp`),
  key (`app_id`, `verb_nobj_id`, `timestamp`),
  key (`app_id`, `operator_nobj_id`, `timestamp`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;

create table if not exists `status_info` (
  `app_id` bigint unsigned not null,
  `target_nobj_id` bigint unsigned not null,
  `data` mediumblob not null,
  `timestamp` double not null,
  primary key (`app_id`, `target_nobj_id`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;

alter table `status_info`
  add column `author_data` mediumblob not null,
  add column `owner_data` mediumblob not null,
  add column `admin_data` mediumblob not null;

create table if not exists `attachment` (
  `app_id` bigint unsigned not null,
  `target_nobj_id` bigint unsigned not null,
  `url` varbinary(511) not null,
  `data` mediumblob not null,
  `open` boolean not null,
  `deleted` boolean not null,
  `created` double not null,
  `modified` double not null,
  primary key (`app_id`, `url`),
  key (`app_id`, `created`),
  key (`app_id`, `target_nobj_id`, `created`),
  key (`created`),
  key (`modified`)
) default charset=binary engine=innodb;

create table if not exists `comment` (
  `app_id` bigint unsigned not null,
  `thread_nobj_id` bigint unsigned not null,
  `comment_id` bigint unsigned not null,
  `author_nobj_id` bigint unsigned not null,
  `data` mediumblob not null,
  `internal_data` mediumblob not null,
  `author_status` tinyint unsigned not null,
  `owner_status` tinyint unsigned not null,
  `admin_status` tinyint unsigned not null,
  `timestamp` double not null,
  primary key (`comment_id`),
  key (`app_id`, `thread_nobj_id`, `timestamp`),
  key (`app_id`, `author_nobj_id`, `timestamp`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;

create table if not exists `star` (
  `app_id` bigint unsigned not null,
  `starred_nobj_id` bigint unsigned not null,
  `starred_author_nobj_id` bigint unsigned not null,
  `starred_index_nobj_id` bigint unsigned not null,
  `author_nobj_id` bigint unsigned not null,
  `count` int unsigned not null,
  `item_nobj_id` bigint unsigned not null,
  `created` double not null,
  `updated` double not null,
  primary key (`app_id`, `starred_nobj_id`, `author_nobj_id`, `item_nobj_id`),
  key (`app_id`, `starred_nobj_id`, `created`),
  key (`app_id`, `author_nobj_id`, `created`),
  key (`app_id`, `starred_author_nobj_id`, `created`),
  key (`app_id`, `starred_index_nobj_id`, `starred_author_nobj_id`, `created`),
  key (`app_id`, `item_nobj_id`, `created`),
  key (`app_id`, `updated`),
  key (`created`),
  key (`updated`)
) default charset=binary engine=innodb;

create table if not exists `follow` (
  `app_id` bigint unsigned not null,
  `subject_nobj_id` bigint unsigned not null,
  `object_nobj_id` bigint unsigned not null,
  `verb_nobj_id` bigint unsigned not null,
  `value` tinyint unsigned not null,
  `timestamp` double not null,
  primary key (`app_id`, `subject_nobj_id`, `object_nobj_id`, `verb_nobj_id`),
  key (`app_id`, `object_nobj_id`, `subject_nobj_id`),
  key (`app_id`, `verb_nobj_id`, `timestamp`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;
alter table `follow`
  add column `created` double not null,
  add key (`app_id`, `verb_nobj_id`, `created`),
  add key (`app_id`, `created`),
  add key (`created`);

create table if not exists `blog_entry` (
  `app_id` bigint unsigned not null,
  `blog_nobj_id` bigint unsigned not null,
  `blog_entry_id` bigint unsigned not null,
  `data` mediumblob not null,
  `internal_data` mediumblob not null,
  `author_status` tinyint unsigned not null,
  `owner_status` tinyint unsigned not null,
  `admin_status` tinyint unsigned not null,
  `timestamp` double not null,
  primary key (`blog_entry_id`),
  key (`app_id`, `blog_nobj_id`, `timestamp`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;

alter table `blog_entry`
  add column `title` varbinary(1023) not null;

alter table `blog_entry`
  add column `summary_data` mediumblob not null;

alter table `blog_entry`
  add column `modified` double not null,
  add key (`app_id`, `modified`);

create table if not exists `tag` (
  `app_id` bigint unsigned not null,
  `context_nobj_id` bigint unsigned not null,
  `name` varbinary(1023) not null,
  `name_sha` binary(40) not null,
  `count` int not null,
  `author_status` tinyint unsigned not null,
  `owner_status` tinyint unsigned not null,
  `admin_status` tinyint unsigned not null,
  `timestamp` double not null,
  primary key (`app_id`, `context_nobj_id`, `name_sha`),
  key (`app_id`, `context_nobj_id`, `timestamp`),
  key (`app_id`, `context_nobj_id`, `count`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;

create table if not exists `tag_redirect` (
  `app_id` bigint unsigned not null,
  `context_nobj_id` bigint unsigned not null,
  `from_name_sha` binary(40) not null,
  `to_name_sha` binary(40) not null,
  `timestamp` double not null,
  primary key (`app_id`, `context_nobj_id`, `from_name_sha`),
  key (`app_id`, `context_nobj_id`, `to_name_sha`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;

create table if not exists `tag_name` (
  `app_id` bigint unsigned not null,
  `context_nobj_id` bigint unsigned not null,
  `primary_name_sha` binary(40) not null,
  `localized_name_sha` binary(40) not null,
  `lang` varbinary(31) not null,
  `timestamp` double not null,
  primary key (`app_id`, `context_nobj_id`, `primary_name_sha`, `lang`),
  key (`app_id`, `context_nobj_id`, `localized_name_sha`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;

create table if not exists `tag_string_data` (
  `app_id` bigint unsigned not null,
  `context_nobj_id` bigint unsigned not null,
  `name_sha` binary(40) not null,
  `name` varbinary(255) not null,
  `value` mediumblob not null,
  `timestamp` double not null,
  primary key (`app_id`, `context_nobj_id`, `name_sha`, `name`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;

create table if not exists `tag_item` (
  `app_id` bigint unsigned not null,
  `context_nobj_id` bigint unsigned not null,
  `name_sha` binary(40) not null,
  `item_nobj_id` bigint unsigned not null,
  `score` double not null,
  `timestamp` double not null,
  primary key (`app_id`, `context_nobj_id`, `name_sha`, `item_nobj_id`),
  key (`app_id`, `context_nobj_id`, `name_sha`, `timestamp`),
  key (`app_id`, `context_nobj_id`, `name_sha`, `score`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;
