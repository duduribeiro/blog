---
layout: post
title:  "Accepting Emojis on a Rails app with MySQL"
date:   2016-03-7 11:07:16 -0300
categories: rails
---
In the past weeks at work, we faced a problem in our application. A user tried to express himself with an emoji in the description field. We were not expecting it then you can imagine what happened. 💥 in production 😱.

![emojis_everywhere](https://cdn-images-1.medium.com/max/800/0*QTCcpZBDToKhJpzX.png)

We received an alert in the team’s chat.

![emojis_everywhere](https://cdn-images-1.medium.com/max/800/0*80MUt99SOl1guZEM.png)

Going through the error details, we can see that MySQL raised an error.

![invalid_statement](https://cdn-images-1.medium.com/max/800/0*TzEinnXN9U9cXgwA.png)

And looking at the request, we can see the emoji in the body attribute:

![body](https://cdn-images-1.medium.com/max/800/0*AFefcxzHWuii1hTu.png)

Why did this happen? Is not [Emoji a unicode character](https://en.wikipedia.org/wiki/Emoticons_%28Unicode_block%29) supported by the UTF8?
**Yes**, it is. But some of them uses **4-bytes** to store their data, and if we look at the [UTF8 charset support at MySQL’s oficial doc](http://dev.mysql.com/doc/refman/5.7/en/charset-unicode-utf8.html), we can see that it can only accept **3-bytes**.

* A maximum of three bytes per multibyte character.

It’s a different approach from Postgres’ UTF8. In [Postgres charset table](http://www.postgresql.org/docs/9.5/static/multibyte.html#CHARSET-TABLE) we see that UTF8 can store up to 4-bytes, meaning that Postgres already accepts Emojis by default.

<div class="divider"></div>

## How to store Emojis on MySQL database and avoid the Incorrect String value error?

Let’s check the [MySQL’s doc](http://dev.mysql.com/doc/refman/5.7/en/charset.html) again. We can see that in charsets support there is one item called [utf8mb4](http://dev.mysql.com/doc/refman/5.7/en/charset-unicode-utf8mb4.html). It’s a UTF8 with **4-bytes** support. We should use it instead the default 3-bytes only.

I created a [simple scaffold](https://github.com/duduribeiro/mysql_emoji_test/) application for demonstration. Let’s use the model `Comment` with 2 properties (body and name).

If we try to save the comment with an emoji on the body, it will raise an exception.

![form](https://cdn-images-1.medium.com/max/800/0*JGf5WWhuW7SaMtti.png)
![exception](https://cdn-images-1.medium.com/max/800/0*lneemsbUVPoEoaXo.png)

Let's generate a migration to convert this table and the columns to utf8mb4

{% highlight shell %}
$ bin/rails g migration change_comments_to_utf8mb4
{% endhighlight %}

and add the following content to the migration:

{% highlight ruby %}
class ChangeCommentsToUtf8mb4 < ActiveRecord::Migration
  def up
    execute "ALTER TABLE comments CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_bin"
    execute "ALTER TABLE comments MODIFY name VARCHAR(191) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin" execute "ALTER TABLE comments MODIFY body TEXT CHARACTER SET utf8mb4 COLLATE utf8mb4_bin"
  end
  def down
    execute "ALTER TABLE comments CONVERT TO CHARACTER SET utf8 COLLATE utf8_bin"
    execute "ALTER TABLE comments MODIFY name VARCHAR(255) CHARACTER SET utf8 COLLATE utf8_bin"
    execute "ALTER TABLE comments MODIFY body TEXT CHARACTER SET utf8 COLLATE utf8_bin"
  end
end
{% endhighlight %}

See that we set the column `name` with `VARCHAR(191)`. This is because [MySQL's max key length for index on InnoDB engine is 767 bytes](http://dev.mysql.com/doc/refman/5.7/en/create-index.html). With `utf8` (3-bytes), we can store VARCHAR with a maximum of 255 chars (255 chars * 3 bytes = 765 bytes), but with `utf8mb4` we can store the maximum of 191 chars (191 chars * 4 bytes = 764 bytes). If you want to store more bytes on the index, please look at [InnoDB large prefix](http://dev.mysql.com/doc/refman/5.7/en/innodb-parameters.html#sysvar_innodb_large_prefix).

{% highlight shell %}
$ bin/rake db:migrate
{% endhighlight %}

We need to change the `database.yml` to set the **encoding** to **utf8mb4**. So, open the `config/database.yml` and change the line with

{% highlight yaml %}
encoding: utf8
{% endhighlight %}

to

{% highlight yaml %}
encoding: utf8mb4
{% endhighlight %}

Restart the server and now we can save emoji in our comment 😎.

![success](https://cdn-images-1.medium.com/max/800/0*kXCaEZQ6ZjH9_1-K.png)

If you are creating a new project, I highly recommend to start with `utf8mb4` to avoid these issues in the future and eliminate the necessity of a migration for all tables or simply use Postgres instead ♥️

Cheers 🍻
