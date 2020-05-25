
Before Starting to Deploy, Make Sure you have a user in your AWS account with Programmatic Access and required roles to access ELB, Autoscaling Group and ElasticCache Redis 
Also Make Sure you have Terraform Version 0.12 and Above as some of the Syntax might throw errors. 

#This Code uses AWS as its Provider. Make Sure you create a directory named .aws under your Home Directory and create a file named credentials
#credentials file contents
[default]
aws_access_key_id = 
aws_secret_access_key = 

