-- 小石榴图文社区数据库初始化脚本
-- 创建数据库（如果不存在）
CREATE DATABASE IF NOT EXISTS `xiaoshiliu` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `xiaoshiliu`;

-- 1. 用户表
CREATE TABLE IF NOT EXISTS `users` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '用户ID',
  `password` varchar(255) DEFAULT NULL COMMENT '密码',
  `user_id` varchar(50) NOT NULL COMMENT '小石榴号',
  `nickname` varchar(100) NOT NULL COMMENT '昵称',
  `email` varchar(100) DEFAULT NULL COMMENT '邮箱',
  `avatar` varchar(500) DEFAULT NULL COMMENT '头像URL',
  `bio` text DEFAULT NULL COMMENT '个人简介',
  `location` varchar(100) DEFAULT NULL COMMENT 'IP属地',
  `follow_count` int(11) DEFAULT 0 COMMENT '关注数',
  `fans_count` int(11) DEFAULT 0 COMMENT '粉丝数',
  `like_count` int(11) DEFAULT 0 COMMENT '获赞数',
  `is_active` tinyint(1) DEFAULT 1 COMMENT '是否激活',
  `last_login_at` timestamp NULL DEFAULT NULL COMMENT '最后登录时间',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  `gender` varchar(10) DEFAULT NULL COMMENT '性别',
  `zodiac_sign` varchar(20) DEFAULT NULL COMMENT '星座',
  `mbti` varchar(4) DEFAULT NULL COMMENT 'MBTI人格类型',
  `education` varchar(50) DEFAULT NULL COMMENT '学历',
  `major` varchar(100) DEFAULT NULL COMMENT '专业',
  `interests` json DEFAULT NULL COMMENT '兴趣爱好（JSON数组）',
  `verified` tinyint(1) DEFAULT 0 COMMENT '认证状态：0-未认证，1-已认证',
  `is_vip` tinyint(1) DEFAULT 0 COMMENT '是否VIP：0-否，1-是',
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_email` (`email`),
  KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户表';

-- 2. 管理员表
CREATE TABLE IF NOT EXISTS `admin` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '管理员ID',
  `username` varchar(50) NOT NULL COMMENT '管理员用户名',
  `password` varchar(255) NOT NULL COMMENT '管理员密码',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `username` (`username`),
  KEY `idx_admin_username` (`username`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='管理员表';

-- 3. 分类表
CREATE TABLE categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) NOT NULL UNIQUE COMMENT '分类名称',
    category_title VARCHAR(50) NULL COMMENT '分类英文标题，用于URL路径',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
    UNIQUE KEY uk_category_title (category_title)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='分类表';

-- 4. 笔记表
CREATE TABLE IF NOT EXISTS `posts` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '笔记ID',
  `user_id` bigint(20) NOT NULL COMMENT '发布用户ID',
  `title` varchar(200) NOT NULL COMMENT '标题',
  `content` text NOT NULL COMMENT '内容',
  `category_id` int(11) DEFAULT NULL COMMENT '分类ID',
  `type` int(11) DEFAULT 1 COMMENT '笔记类型：1-图片笔记，2-视频笔记',
  `music_id` bigint(20) DEFAULT NULL COMMENT '关联音乐ID',
  `view_count` bigint(20) DEFAULT 0 COMMENT '浏览量',
  `like_count` int(11) DEFAULT 0 COMMENT '点赞数',
  `collect_count` int(11) DEFAULT 0 COMMENT '收藏数',
  `comment_count` int(11) DEFAULT 0 COMMENT '评论数',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '发布时间',
  `status` tinyint(1) DEFAULT 2 COMMENT '笔记状态：0-发布（审核通过），1-草稿，2-待审核',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_category_id` (`category_id`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_like_count` (`like_count`),
  KEY `idx_category_id_created_at` (`category_id`, `created_at`),
  CONSTRAINT `posts_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_posts_category` FOREIGN KEY (`category_id`) REFERENCES `categories` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='笔记表';

-- 5. 笔记图片表
CREATE TABLE IF NOT EXISTS `post_images` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '图片ID',
  `post_id` bigint(20) NOT NULL COMMENT '笔记ID',
  `image_url` varchar(500) NOT NULL COMMENT '图片URL',
  PRIMARY KEY (`id`),
  KEY `idx_post_id` (`post_id`),
  CONSTRAINT `post_images_ibfk_1` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='笔记图片表';

-- 6. 笔记视频表
CREATE TABLE IF NOT EXISTS `post_videos` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '视频ID',
  `post_id` bigint(20) NOT NULL COMMENT '笔记ID',
  `cover_url` varchar(500) DEFAULT NULL COMMENT '视频封面URL',
  `video_url` varchar(500) NOT NULL COMMENT '视频URL',
  PRIMARY KEY (`id`),
  KEY `idx_post_id` (`post_id`),
  CONSTRAINT `post_videos_ibfk_1` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='笔记视频表';

-- 6b. 笔记剧集分集表（一部剧集帖对应多条分集，按 sort 升序播放）
CREATE TABLE IF NOT EXISTS `post_episodes` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '分集ID',
  `post_id` bigint(20) NOT NULL COMMENT '所属剧集笔记ID',
  `title` varchar(200) NOT NULL COMMENT '分集标题（如 第01集）',
  `video_url` varchar(500) NOT NULL COMMENT '分集播放地址（m3u8/mp4）',
  `cover_url` varchar(500) DEFAULT NULL COMMENT '分集封面URL（可空，回退帖子封面）',
  `sort` int(11) NOT NULL DEFAULT 0 COMMENT '集序，升序排列',
  PRIMARY KEY (`id`),
  KEY `idx_post_id_sort` (`post_id`, `sort`),
  CONSTRAINT `post_episodes_ibfk_1` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='笔记剧集分集表';

-- 7. 标签表
CREATE TABLE IF NOT EXISTS `tags` (
  `id` int(11) NOT NULL AUTO_INCREMENT COMMENT '标签ID',
  `name` varchar(50) NOT NULL COMMENT '标签名',
  `use_count` int(11) DEFAULT 0 COMMENT '使用次数',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `name` (`name`),
  KEY `idx_name` (`name`),
  KEY `idx_use_count` (`use_count`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='标签表';

-- 8. 笔记标签关联表
CREATE TABLE IF NOT EXISTS `post_tags` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '关联ID',
  `post_id` bigint(20) NOT NULL COMMENT '笔记ID',
  `tag_id` int(11) NOT NULL COMMENT '标签ID',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_post_tag` (`post_id`, `tag_id`),
  KEY `idx_post_id` (`post_id`),
  KEY `idx_tag_id` (`tag_id`),
  CONSTRAINT `post_tags_ibfk_1` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `post_tags_ibfk_2` FOREIGN KEY (`tag_id`) REFERENCES `tags` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='笔记标签关联表';

-- 9. 关注关系表
CREATE TABLE IF NOT EXISTS `follows` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '关注ID',
  `follower_id` bigint(20) NOT NULL COMMENT '关注者ID',
  `following_id` bigint(20) NOT NULL COMMENT '被关注者ID',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '关注时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_follow` (`follower_id`, `following_id`),
  KEY `idx_follower_id` (`follower_id`),
  KEY `idx_following_id` (`following_id`),
  KEY `idx_follower_following` (`follower_id`, `following_id`),
  CONSTRAINT `follows_ibfk_1` FOREIGN KEY (`follower_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `follows_ibfk_2` FOREIGN KEY (`following_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='关注关系表';

-- 10. 点赞表
CREATE TABLE IF NOT EXISTS `likes` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '点赞ID',
  `user_id` bigint(20) NOT NULL COMMENT '用户ID',
  `target_type` tinyint(4) NOT NULL COMMENT '目标类型: 1-笔记, 2-评论',
  `target_id` bigint(20) NOT NULL COMMENT '目标ID',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '点赞时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_target` (`user_id`, `target_type`, `target_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_target` (`target_type`, `target_id`),
  KEY `idx_user_target_type` (`user_id`, `target_type`, `target_id`),
  CONSTRAINT `likes_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='点赞表';

-- 11. 收藏表
CREATE TABLE IF NOT EXISTS `collections` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '收藏ID',
  `user_id` bigint(20) NOT NULL COMMENT '用户ID',
  `post_id` bigint(20) NOT NULL COMMENT '笔记ID',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '收藏时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_post` (`user_id`, `post_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_post_id` (`post_id`),
  CONSTRAINT `collections_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `collections_ibfk_2` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='收藏表';

-- 12. 评论表
CREATE TABLE IF NOT EXISTS `comments` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '评论ID',
  `post_id` bigint(20) NOT NULL COMMENT '笔记ID',
  `user_id` bigint(20) NOT NULL COMMENT '评论用户ID',
  `parent_id` bigint(20) DEFAULT NULL COMMENT '父评论ID',
  `content` text NOT NULL COMMENT '评论内容',
  `like_count` int(11) DEFAULT 0 COMMENT '点赞数',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '评论时间',
  PRIMARY KEY (`id`),
  KEY `idx_post_id` (`post_id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_parent_id` (`parent_id`),
  KEY `idx_created_at` (`created_at`),
  CONSTRAINT `comments_ibfk_1` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `comments_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `comments_ibfk_3` FOREIGN KEY (`parent_id`) REFERENCES `comments` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='评论表';

-- 13. 通知表
CREATE TABLE IF NOT EXISTS `notifications` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '通知ID',
  `user_id` bigint(20) NOT NULL COMMENT '接收用户ID',
  `sender_id` bigint(20) NOT NULL COMMENT '发送用户ID',
  `type` tinyint(4) NOT NULL COMMENT '通知类型: 1-点赞, 2-评论, 3-关注',
  `title` varchar(200) NOT NULL COMMENT '通知标题',
  `target_id` bigint(20) DEFAULT NULL COMMENT '关联目标ID',
  `comment_id` bigint(20) DEFAULT NULL COMMENT '关联评论ID，用于评论和回复通知',
  `is_read` tinyint(1) DEFAULT 0 COMMENT '是否已读',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '通知时间',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_sender_id` (`sender_id`),
  KEY `idx_type` (`type`),
  KEY `idx_is_read` (`is_read`),
  KEY `idx_user_read` (`user_id`, `is_read`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_notifications_comment_id` (`comment_id`),
  CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `notifications_ibfk_2` FOREIGN KEY (`sender_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `fk_notifications_comment_id` FOREIGN KEY (`comment_id`) REFERENCES `comments` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='通知表';

-- 14. 用户会话表
CREATE TABLE IF NOT EXISTS `user_sessions` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '会话ID',
  `user_id` bigint(20) NOT NULL COMMENT '用户ID',
  `token` varchar(255) NOT NULL COMMENT '访问令牌',
  `refresh_token` varchar(255) DEFAULT NULL COMMENT '刷新令牌',
  `expires_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '过期时间',
  `user_agent` text DEFAULT NULL COMMENT '用户代理',
  `is_active` tinyint(1) DEFAULT 1 COMMENT '是否激活',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `token` (`token`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_token` (`token`),
  KEY `idx_expires_at` (`expires_at`),
  CONSTRAINT `user_sessions_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户会话表';

-- 15. 管理员会话表
CREATE TABLE IF NOT EXISTS `admin_sessions` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '会话ID',
  `admin_id` bigint(20) NOT NULL COMMENT '管理员ID',
  `token` varchar(255) NOT NULL COMMENT '访问令牌',
  `refresh_token` varchar(255) DEFAULT NULL COMMENT '刷新令牌',
  `expires_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '过期时间',
  `user_agent` text DEFAULT NULL COMMENT '用户代理',
  `is_active` tinyint(1) DEFAULT 1 COMMENT '是否激活',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT '更新时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `token` (`token`),
  KEY `idx_admin_id` (`admin_id`),
  KEY `idx_token` (`token`),
  KEY `idx_expires_at` (`expires_at`),
  CONSTRAINT `admin_sessions_ibfk_1` FOREIGN KEY (`admin_id`) REFERENCES `admin` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='管理员会话表';

-- 16. 审核表
CREATE TABLE IF NOT EXISTS `audit` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '审核ID',
  `admin_id` bigint(20) DEFAULT NULL COMMENT '审核人ID（管理员ID）',
  `type` tinyint(4) NOT NULL COMMENT '审核类型：1-用户个人审核，2-用户官方审核，3-内容审核，4-评论审核',
  `target_id` bigint(20) NOT NULL COMMENT '目标ID：根据type不同，对应用户ID、笔记ID或评论ID',
  `remark` text DEFAULT NULL COMMENT '审核备注',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `audit_time` timestamp NULL DEFAULT NULL COMMENT '审核时间',
  `status` tinyint(1) DEFAULT 0 COMMENT '审核状态：0-待审核，1-审核通过，2-审核拒绝',
  PRIMARY KEY (`id`),
  KEY `idx_admin_id` (`admin_id`),
  KEY `idx_type` (`type`),
  KEY `idx_target_id` (`target_id`),
  KEY `idx_status` (`status`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_type_target` (`type`, `target_id`),
  CONSTRAINT `audit_ibfk_1` FOREIGN KEY (`admin_id`) REFERENCES `admin` (`id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='审核表';

-- 17. 用户认证表
CREATE TABLE IF NOT EXISTS `user_verification` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '主键ID',
  `user_id` bigint(20) NOT NULL COMMENT '用户ID',
  `type` tinyint(4) NOT NULL COMMENT '认证类型：1=官方认证 2=个人认证',
  `status` tinyint(4) DEFAULT 0 COMMENT '认证状态：0=待审核 1=已通过 2=已拒绝',
  `real_name` varchar(200) NOT NULL COMMENT '真实姓名/机构名称',
  `id_card` varchar(18) NOT NULL COMMENT '身份证号/信用代码',
  `contact_name` varchar(50) DEFAULT NULL COMMENT '联系人姓名',
  `contact_phone` varchar(20) DEFAULT NULL COMMENT '联系电话',
  `title` varchar(100) DEFAULT NULL COMMENT '认证称号',
  `description` text DEFAULT NULL COMMENT '认证理由',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_user_id` (`user_id`),
  KEY `idx_type` (`type`),
  KEY `idx_status` (`status`),
  CONSTRAINT `user_verification_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户认证表';

-- 18. 用户封禁表
CREATE TABLE IF NOT EXISTS `user_ban` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT COMMENT '封禁记录ID',
  `user_id` bigint(20) NOT NULL COMMENT '用户ID',
  `reason` text NOT NULL COMMENT '封禁原因',
  `end_time` timestamp NULL DEFAULT NULL COMMENT '封禁结束时间',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '创建时间',
  `status` tinyint(4) DEFAULT 0 COMMENT '状态：0=封禁中，1=管理员解封，2=自动解封，3=永久封禁，4=封禁撤销',
  `operator` bigint(20) NOT NULL COMMENT '操作人ID',
  PRIMARY KEY (`id`),
  KEY `idx_user_id` (`user_id`),
  KEY `idx_status` (`status`),
  KEY `idx_created_at` (`created_at`),
  KEY `idx_operator` (`operator`),
  CONSTRAINT `user_ban_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户封禁表';

-- 插入默认管理员账户
-- 密码: 123456
INSERT INTO `admin` (`username`, `password`) VALUES 
('admin', '8d969eef6ecad3c29a3a629280e686cf0c3f5d5a86aff3ca12020c923adc6c92')
ON DUPLICATE KEY UPDATE `username` = VALUES(`username`);

-- ============================================================
-- 19-30. UI 功能扩展表（详见 scripts/migrate-ui-features.sql）
-- ============================================================
CREATE TABLE IF NOT EXISTS `musics` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `title` varchar(200) NOT NULL COMMENT '歌曲名',
  `author` varchar(100) DEFAULT NULL COMMENT '作者',
  `audio_url` varchar(500) NOT NULL COMMENT '音频URL',
  `cover_url` varchar(500) DEFAULT NULL COMMENT '封面URL',
  `duration` int(11) DEFAULT 0 COMMENT '时长（秒）',
  `use_count` int(11) DEFAULT 0 COMMENT '使用次数',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_use_count` (`use_count`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='音乐库表';

ALTER TABLE `posts` ADD CONSTRAINT `fk_posts_music` FOREIGN KEY (`music_id`) REFERENCES `musics` (`id`) ON DELETE SET NULL;

CREATE TABLE IF NOT EXISTS `polls` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `post_id` bigint(20) NOT NULL,
  `question` varchar(255) NOT NULL,
  `ends_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uk_post` (`post_id`),
  CONSTRAINT `polls_ibfk_1` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='投票表';

CREATE TABLE IF NOT EXISTS `poll_options` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `poll_id` bigint(20) NOT NULL,
  `content` varchar(255) NOT NULL,
  `vote_count` int(11) DEFAULT 0,
  `sort_order` int(11) DEFAULT 0,
  PRIMARY KEY (`id`), KEY `idx_poll_id` (`poll_id`),
  CONSTRAINT `poll_options_ibfk_1` FOREIGN KEY (`poll_id`) REFERENCES `polls` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='投票选项表';

CREATE TABLE IF NOT EXISTS `poll_votes` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `poll_id` bigint(20) NOT NULL,
  `option_id` bigint(20) NOT NULL,
  `user_id` bigint(20) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), UNIQUE KEY `uk_poll_user` (`poll_id`, `user_id`),
  CONSTRAINT `poll_votes_ibfk_1` FOREIGN KEY (`poll_id`) REFERENCES `polls` (`id`) ON DELETE CASCADE,
  CONSTRAINT `poll_votes_ibfk_2` FOREIGN KEY (`option_id`) REFERENCES `poll_options` (`id`) ON DELETE CASCADE,
  CONSTRAINT `poll_votes_ibfk_3` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='投票记录表';

CREATE TABLE IF NOT EXISTS `danmaku` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `post_id` bigint(20) NOT NULL,
  `user_id` bigint(20) NOT NULL,
  `content` varchar(255) NOT NULL,
  `offset_sec` int(11) DEFAULT 0,
  `color` varchar(9) DEFAULT '#FFFFFF',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_post_offset` (`post_id`, `offset_sec`),
  CONSTRAINT `danmaku_ibfk_1` FOREIGN KEY (`post_id`) REFERENCES `posts` (`id`) ON DELETE CASCADE,
  CONSTRAINT `danmaku_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='弹幕表';

CREATE TABLE IF NOT EXISTS `search_logs` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) DEFAULT NULL,
  `keyword` varchar(100) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_keyword` (`keyword`), KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='搜索记录表';

CREATE TABLE IF NOT EXISTS `user_wallets` (
  `user_id` bigint(20) NOT NULL,
  `coin_balance` int(11) NOT NULL DEFAULT 0,
  `updated_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`user_id`),
  CONSTRAINT `user_wallets_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户钱包表';

CREATE TABLE IF NOT EXISTS `coin_transactions` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) NOT NULL,
  `amount` int(11) NOT NULL,
  `type` tinyint(4) NOT NULL COMMENT '1-收入，2-支出',
  `scene` varchar(50) NOT NULL,
  `balance_after` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_user_id` (`user_id`),
  CONSTRAINT `coin_transactions_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='金币流水表';

CREATE TABLE IF NOT EXISTS `coin_earn_rules` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `code` varchar(50) NOT NULL COMMENT '规则编码：comment/danmaku/watch_ad/watch_video/publish_note/publish_video',
  `name` varchar(50) NOT NULL COMMENT '获取方式名称',
  `description` varchar(255) DEFAULT NULL COMMENT '说明文案',
  `reward_coin` int(11) NOT NULL DEFAULT 0 COMMENT '每次奖励金币数',
  `daily_limit` int(11) NOT NULL DEFAULT 0 COMMENT '每日次数上限，0-不限',
  `auto_reward` tinyint(1) NOT NULL DEFAULT 0 COMMENT '1-完成行为自动发放，0-用户手动领取',
  `enabled` tinyint(1) NOT NULL DEFAULT 1 COMMENT '1-启用，0-停用',
  `sort_order` int(11) NOT NULL DEFAULT 0 COMMENT '排序值，越小越靠前',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uk_code` (`code`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='金币获取方式表';

CREATE TABLE IF NOT EXISTS `vip_plans` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `name` varchar(50) NOT NULL,
  `level` tinyint(4) NOT NULL DEFAULT 1,
  `price_coin` int(11) NOT NULL,
  `duration_days` int(11) NOT NULL,
  `perks_json` json DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='VIP套餐表';

CREATE TABLE IF NOT EXISTS `user_vip` (
  `user_id` bigint(20) NOT NULL,
  `plan_id` bigint(20) DEFAULT NULL,
  `level` tinyint(4) NOT NULL DEFAULT 0,
  `start_at` timestamp NULL DEFAULT NULL,
  `expire_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`user_id`),
  CONSTRAINT `user_vip_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='用户会员表';

CREATE TABLE IF NOT EXISTS `products` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `name` varchar(200) NOT NULL,
  `cover_url` varchar(500) DEFAULT NULL,
  `price_coin` int(11) NOT NULL,
  `stock` int(11) NOT NULL DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='商品表';

CREATE TABLE IF NOT EXISTS `orders` (
  `id` bigint(20) NOT NULL AUTO_INCREMENT,
  `user_id` bigint(20) NOT NULL,
  `product_id` bigint(20) NOT NULL,
  `quantity` int(11) NOT NULL DEFAULT 1,
  `total_coin` int(11) NOT NULL,
  `status` tinyint(4) NOT NULL DEFAULT 0 COMMENT '0-待发货，1-已发货，2-已完成',
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_user_id` (`user_id`),
  CONSTRAINT `orders_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `orders_ibfk_2` FOREIGN KEY (`product_id`) REFERENCES `products` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单表';

INSERT IGNORE INTO `vip_plans` (`id`, `name`, `level`, `price_coin`, `duration_days`, `perks_json`) VALUES
(1, '超级会员·月卡', 1, 1000, 30, JSON_ARRAY('高清画质', '去广告', '抢先看')),
(2, '超级会员·季卡', 2, 2700, 90, JSON_ARRAY('高清画质', '去广告', '抢先看', '专属标识')),
(3, '超级会员·年卡', 3, 9800, 365, JSON_ARRAY('高清画质', '去广告', '抢先看', '专属标识', '客服优先')),
(4, '超级会员·钻石月卡', 4, 1800, 30, JSON_ARRAY('高清画质', '去广告', '抢先看', '专属标识', '蓝光1080P')),
(5, '超级会员·钻石季卡', 5, 4800, 90, JSON_ARRAY('高清画质', '去广告', '抢先看', '专属标识', '蓝光1080P', '评论置顶')),
(6, '超级会员·至尊年卡', 6, 16800, 365, JSON_ARRAY('高清画质', '去广告', '抢先看', '专属标识', '蓝光1080P', '评论置顶', '直播特权', '客服优先')),
(7, '超级会员·皇冠年卡', 7, 28800, 365, JSON_ARRAY('高清画质', '去广告', '抢先看', '专属标识', '蓝光1080P', '评论置顶', '直播特权', '客服优先', '专属装扮', '优先体验'));

INSERT IGNORE INTO `coin_earn_rules` (`code`, `name`, `description`, `reward_coin`, `daily_limit`, `auto_reward`, `enabled`, `sort_order`) VALUES
('watch_ad', '看广告', '观看一段激励广告即可领取金币', 10, 5, 0, 1, 1),
('watch_video', '看视频', '观看视频达到时长即可领取金币', 5, 10, 0, 1, 2),
('publish_video', '发视频', '发布一条视频笔记，审核通过后自动发放', 50, 3, 1, 1, 3),
('publish_note', '发表内容', '发布图文笔记，审核通过后自动发放', 30, 3, 1, 1, 4),
('comment', '发表评论', '发表一条评论自动发放', 5, 10, 1, 1, 5),
('danmaku', '发弹幕', '发送一条弹幕自动发放', 2, 20, 1, 1, 6);

INSERT IGNORE INTO `products` (`id`, `name`, `price_coin`, `stock`) VALUES
(1, '小石榴官方周边 T恤', 5000, 100),
(2, '石榴籽保温杯', 8000, 50),
(3, '创作者徽章套装', 3000, 200);

-- 注意：默认数据插入请使用专门的数据生成脚本

-- 数据库初始化完成
SELECT '数据库初始化完成！' AS message;
SELECT COUNT(*) AS table_count FROM information_schema.tables WHERE table_schema = 'xiaoshiliu';