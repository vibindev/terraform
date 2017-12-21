# Creating EC2 Instance
resource "aws_instance" "web-server" {
  ami           = "ami-bf4193c7"
  instance_type = "t2.micro"
  tag           = "Web Server"

  user_data = <<USER_DATA
 #!/bin/bash
 yum update -y
 yum install -y httpd24 php56 mysql55-server php56-mysqlnd
 service httpd start
 chkconfig httpd on
 groupadd www
 usermod -a -G www ec2-user
 chown -R root:www /var/www
 chmod 2775 /var/www
 find /var/www -type d -exec chmod 2775 {} +
 find /var/www -type f -exec chmod 0664 {} +
 echo "<?php phpinfo(); ?>" > /var/www/html/phpinfo.php
 USER_DATA
}
