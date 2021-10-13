-- create database apploach;

create table if not exists `nobj` (
  `app_id` bigint unsigned not null,
  `nobj_id` bigint unsigned not null,
  `nobj_key` varbinary(4095) not null,
  `nobj_key_sha` binary(40) not null,
  `timestamp` double not null,
  primary key (`nobj_id`),
  key `app_id` (`app_id`, `nobj_key_sha`),
  key `app_id_2` (`app_id`, `timestamp`),
  key `timestamp` (`timestamp`)
) default charset=binary engine=innodb;

alter table `nobj`
  drop key `app_id`,
  add unique key `app_id` (`app_id`, `nobj_key_sha`);

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

alter table `log`
    add column `target_index_nobj_id` bigint unsigned not null default 0,
    add key (`app_id`, `target_index_nobj_id`, `timestamp`);

create table if not exists `revision` (
  `app_id` bigint unsigned not null,
  `revision_id` bigint unsigned not null,
  `target_nobj_id` bigint unsigned not null,
  `author_nobj_id` bigint unsigned not null,
  `operator_nobj_id` bigint unsigned not null,
  `summary_data` mediumblob not null,
  `data` mediumblob not null,
  `revision_data` mediumblob not null,
  `author_status` tinyint unsigned not null,
  `owner_status` tinyint unsigned not null,
  `admin_status` tinyint unsigned not null,
  `timestamp` double not null,
  primary key (`revision_id`),
  key (`app_id`, `target_nobj_id`, `timestamp`),
  key (`app_id`, `author_nobj_id`, `timestamp`),
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
  `tag_name` varbinary(1023) not null,
  `tag_name_sha` binary(40) not null,
  `count` int not null,
  `author_status` tinyint unsigned not null,
  `owner_status` tinyint unsigned not null,
  `admin_status` tinyint unsigned not null,
  `timestamp` double not null,
  primary key (`app_id`, `context_nobj_id`, `tag_name_sha`),
  key (`app_id`, `context_nobj_id`, `timestamp`),
  key (`app_id`, `context_nobj_id`, `count`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;

create table if not exists `tag_redirect` (
  `app_id` bigint unsigned not null,
  `context_nobj_id` bigint unsigned not null,
  `from_tag_name_sha` binary(40) not null,
  `to_tag_name_sha` binary(40) not null,
  `timestamp` double not null,
  primary key (`app_id`, `context_nobj_id`, `from_tag_name_sha`),
  key (`app_id`, `context_nobj_id`, `to_tag_name_sha`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;

create table if not exists `tag_name` (
  `app_id` bigint unsigned not null,
  `context_nobj_id` bigint unsigned not null,
  `tag_name_sha` binary(40) not null,
  `localized_tag_name_sha` binary(40) not null,
  `localized_tag_name` varbinary(1023) not null,
  `lang` varbinary(31) not null,
  `timestamp` double not null,
  primary key (`app_id`, `context_nobj_id`, `tag_name_sha`, `lang`),
  key (`app_id`, `context_nobj_id`, `localized_tag_name_sha`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;

create table if not exists `tag_string_data` (
  `app_id` bigint unsigned not null,
  `context_nobj_id` bigint unsigned not null,
  `tag_name_sha` binary(40) not null,
  `name` varbinary(255) not null,
  `value` mediumblob not null,
  `timestamp` double not null,
  primary key (`app_id`, `context_nobj_id`, `tag_name_sha`, `name`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;

create table if not exists `tag_item` (
  `app_id` bigint unsigned not null,
  `context_nobj_id` bigint unsigned not null,
  `tag_name_sha` binary(40) not null,
  `item_nobj_id` bigint unsigned not null,
  `score` double not null,
  `timestamp` double not null,
  primary key (`app_id`, `context_nobj_id`, `tag_name_sha`, `item_nobj_id`),
  key (`app_id`, `context_nobj_id`, `tag_name_sha`, `timestamp`),
  key (`app_id`, `context_nobj_id`, `tag_name_sha`, `score`),
  key (`app_id`, `context_nobj_id`, `timestamp`),
  key (`app_id`, `context_nobj_id`, `score`),
  key (`app_id`, `item_nobj_id`, `timestamp`),
  key (`app_id`, `timestamp`),
  key (`timestamp`)
) default charset=binary engine=innodb;

create table if not exists `topic_subscription` (
  `app_id` bigint unsigned not null,
  `topic_nobj_id` bigint unsigned not null,
  `topic_index_nobj_id` bigint unsigned not null,
  `subscriber_nobj_id` bigint unsigned not null,
  `channel_nobj_id` bigint unsigned not null,
  `created` double not null,
  `updated` double not null,
  `status` tinyint unsigned not null,
  `data` mediumblob not null,
  primary key (`app_id`, `topic_nobj_id`, `subscriber_nobj_id`, `channel_nobj_id`),
  key (`app_id`, `topic_nobj_id`, `updated`),
  key (`app_id`, `subscriber_nobj_id`, `updated`),
  key (`app_id`, `subscriber_nobj_id`, `topic_index_nobj_id`, `updated`),
  key (`created`),
  key (`updated`)
) default charset=binary engine=innodb;

alter table `topic_subscription`
  add key (`app_id`, `topic_index_nobj_id`);

create table if not exists `nevent` (
  `app_id` bigint unsigned not null,
  `nevent_id` bigint unsigned not null,
  `topic_nobj_id` bigint unsigned not null,
  `subscriber_nobj_id` bigint unsigned not null,
  `unique_nevent_key` binary(40) not null,
  `data` mediumblob not null,
  `timestamp` double not null,
  `expires` double not null,
  primary key (`app_id`, `nevent_id`, `subscriber_nobj_id`),
  unique key (`app_id`, `subscriber_nobj_id`, `unique_nevent_key`),
  key (`app_id`, `subscriber_nobj_id`, `timestamp`),
  key (`timestamp`),
  key (`expires`)
) default charset=binary engine=innodb;

create table if not exists `nevent_queue` (
  `app_id` bigint unsigned not null,
  `nevent_id` bigint unsigned not null,
  `channel_nobj_id` bigint unsigned not null,
  `subscriber_nobj_id` bigint unsigned not null,
  `topic_subscription_data` mediumblob not null,
  `timestamp` double not null,
  `expires` double not null,
  `locked` double not null,
  `result_done` tinyint unsigned not null,
  `result_data` mediumblob not null,
  primary key (`app_id`, `nevent_id`, `subscriber_nobj_id`, `channel_nobj_id`),
  key (`app_id`, `channel_nobj_id`, `timestamp`),
  key (`timestamp`),
  key (`expires`)
) default charset=binary engine=innodb;

create table if not exists `nevent_list` (
  `app_id` bigint unsigned not null,
  `subscriber_nobj_id` bigint unsigned not null,
  `last_checked` double not null,
  primary key (`app_id`, `subscriber_nobj_id`),
  key (`last_checked`)
) default charset=binary engine=innodb;

create table if not exists `hook` (
  `app_id` bigint unsigned not null,
  `subscriber_nobj_id` bigint unsigned not null,
  `type_nobj_id` bigint unsigned not null,
  `url_sha` binary(40) not null,
  `url` varbinary(2047) not null,
  `created` double not null,
  `updated` double not null,
  `status` tinyint unsigned not null,
  `data` mediumblob not null,
  primary key (`app_id`, `subscriber_nobj_id`, `type_nobj_id`, `url_sha`),
  key (`app_id`, `subscriber_nobj_id`, `updated`),
  key (`created`),
  key (`updated`)
) default charset=binary engine=innodb;

alter table `hook`
  add column `expires` double not null,
  add key (`expires`);

create table if not exists `day_stats` (
  `app_id` bigint unsigned not null,
  `item_nobj_id` bigint unsigned not null,
  `day` double not null,
  `value_all` double not null,
  `value_1` double not null,
  `value_7` double not null,
  `value_30` double not null,
  `created` double not null,
  `updated` double not null,
  primary key (`app_id`, `item_nobj_id`, `day`),
  key (`app_id`, `item_nobj_id`, `value_all`),
  key (`app_id`, `item_nobj_id`, `value_1`),
  key (`app_id`, `item_nobj_id`, `created`),
  key (`app_id`, `item_nobj_id`, `updated`),
  key (`app_id`, `day`, `item_nobj_id`),
  key (`created`)
) default charset=binary engine=innodb;

create table if not exists `fetch_job` (
  `job_id` bigint unsigned not null,
  `origin` varbinary(2047) not null,
  `options` mediumblob not null,
  `running_since` double not null,
  `run_after` double not null,
  `inserted` double not null,
  `expires` double not null,
  primary key (`job_id`),
  key (`run_after`, `running_since`, `inserted`),
  key (`running_since`),
  key (`expires`)
) default charset=binary engine=innodb;
