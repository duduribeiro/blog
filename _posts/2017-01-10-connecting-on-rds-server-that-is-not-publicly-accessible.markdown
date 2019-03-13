---
layout: post
title:  "Connecting on RDS Server that is not publicly accessible"
date:   2017-01-10 12:00:00 -0300
categories: aws rds vpc
---
Let’s imagine the following scenario:

![scenario](https://cdn-images-1.medium.com/max/800/1*hywIXPeJfZtsmJylpYPhNw.png)

You have web servers on a public subnet that you can connect and your RDS instance is hosted on a private subnet. This way, your database instance is not publicly accessible through the internet and you can’t connect your local client with it.

It’s not possible to do a:

{% highlight shell %}
mysql -u user -p -h RDS_HOST
{% endhighlight %}

To establish a connection with the database, you’ll need to use your public EC2 instances to act as a bridge to the RDS. Let’s make a SSH Tunnel.

{% highlight shell %}
ssh -i /path/to/keypair.pem -NL 9000:RDS_ENDPOINT:3306 ec2-user@EC2_HOST -v
{% endhighlight %}

* **-i /path/to/keypair.pem**: The -i option will inform the ssh which key will be used to connect. If you already added your key with ssh-add, this is not necessary.

* **-NL**: **N** will not open a session with the server. It will set up the tunnel. **L** will set up the port forwarding.

* **9000:RDS_ENDPOINT:3306**: The -L option will make the port forwarding based on this argument. The first number 9000 is the local port that you want to use to connect with the remote host. RDS_ENDPOINT is the RDS host of your database instance. 3306 is the port of the remote host that you want to access (3306 is the MySQL’s default port).

* **ec2-user@EC2_HOST**: How ssh your public EC2 instance.

* **-v**: Is optional. With this you will print the ssh log on your terminal.

With this you can now connect to your private RDS instance using your local client.

{% highlight shell %}
mysql -h 127.0.0.1 -P9000 -u RDS_USER -p
{% endhighlight %}

If your EC2 instance is on a private subnet too, you will need to set up a bastion host to make the bridge possible. Bastion host is an instance that will be placed on a public subnet and will be accessible using SSH. You will use the same SSH tunnel, only changing the host used to point the bastion host.

Cheers 🍻
