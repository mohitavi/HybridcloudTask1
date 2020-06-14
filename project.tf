provider "aws" {
  profile = "vimal"
  region  = "ap-south-1"
}


resource "aws_security_group" "sec_grp" {
  name        = "sec_grp"
  description = "Allows SSH and HTTP"
  vpc_id      = "vpc-2a879a42"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }
 
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "sec_grp"
  }
}



resource "tls_private_key" "mykey" {
  algorithm = "RSA"
}

resource "aws_key_pair" "generated_key" {
  key_name   = "mykey"
  public_key = "${tls_private_key.mykey.public_key_openssh}"


  depends_on = [
    tls_private_key.mykey
  ]
}

resource "local_file" "key-file" {
  content  = "${tls_private_key.mykey.private_key_pem}"
  filename = "mykey.pem"


  depends_on = [
    tls_private_key.mykey
  ]
}



resource "aws_instance" "Task1" {
  ami           = "ami-0447a12f28fddb066"  
  instance_type = "t2.micro"
  key_name = aws_key_pair.generated_key.key_name
  security_groups = [ aws_security_group.sec_grp.name ]

  provisioner "remote-exec" {
    connection {
    agent    = "false"
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.mykey.private_key_pem}"
    host     = "${aws_instance.Task1.public_ip}"
  }
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "Task1"
  }
}

resource "aws_ebs_volume" "myebs1" {
  availability_zone = aws_instance.Task1.availability_zone
  size              = 1

  tags = {
    Name = "ebsvol"
  }
}



resource "aws_volume_attachment" "attach_ebs" {
  device_name = "/dev/sdh"
  volume_id   = aws_ebs_volume.myebs1.id
  instance_id = aws_instance.Task1.id
  force_detach = true
}




output "myip" {
  value = aws_instance.Task1.public_ip
}

resource "null_resource" "nullip" {
  provisioner "local-exec" {
    command = "echo ${aws_instance.Task1.public_ip} > publicip.txt"
  }
}


resource "null_resource" "nullmount" {
  depends_on = [
    aws_volume_attachment.attach_ebs,
  ]

  connection {
    agent    = "false"
    type     = "ssh"
    user     = "ec2-user"
    private_key = "${tls_private_key.mykey.private_key_pem}"
    host     = "${aws_instance.Task1.public_ip}"
  }
  provisioner "remote-exec" {
    inline = [
      "sudo mkfs.ext4 /dev/xvdh",
      "sudo mount /dev/xvdh /var/www/html",
      "sudo rm -rf /var/www/html/*",
      "sudo git clone https://github.com/mohitavi/HybridcloudTask1.git  /var/www/html"
    ]
  }
}


resource "aws_s3_bucket" "terra-buckcbuck" {
  bucket = "mkvnewbucket"
  acl    = "public-read"

  versioning {
    enabled = true
  }
 
  tags = {
    Name = "my-new-buck"
    Environment = "Dev"
  }
}



resource "aws_cloudfront_distribution" "tera-cloufront1" {
    origin {
        domain_name = "mkvnewbucket.s3.amazonaws.com"
        origin_id = "S3-mkvnewbucket"


        custom_origin_config {
            http_port = 80
            https_port = 80
            origin_protocol_policy = "match-viewer"
            origin_ssl_protocols = ["TLSv1", "TLSv1.1", "TLSv1.2"]
        }
    }
       
    enabled = true


    default_cache_behavior {
        allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
        cached_methods = ["GET", "HEAD"]
        target_origin_id = "S3-mkvnewbucket"

        forwarded_values {
            query_string = false
        
            cookies {
               forward = "none"
            }
        }
        viewer_protocol_policy = "allow-all"
        min_ttl = 0
        default_ttl = 3600
        max_ttl = 86400
    }
 
    restrictions {
        geo_restriction {
           
            restriction_type = "none"
        }
    }

    viewer_certificate {
        cloudfront_default_certificate = true

    }
}

/*
resource "null_resource" "nullremote" {
  depends_on = [
    null_resource.nullmount,
  ]
 
  provisioner "local-exec" {
    command = "firefox ${aws_instance.os1.public_ip}"
  }
}
*/
