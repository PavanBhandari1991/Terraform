
# TERRAFORM AUTOSCALING 

### Before Starting to Deploy, Make Sure you have a user in your AWS account with Programmatic Access and required roles to access ELB, Autoscaling Group and ElasticCache Redis

#### Also Make Sure you have Terraform Version 0.12 and Above as some of the Syntax might throw errors

#### This Code uses AWS as its Provider. Make Sure you create a directory named .aws under your Home Directory and create a file named credentials

#### Credentials file contents
```
[default]
aws_access_key_id = ***
aws_secret_access_key = *** 
```

Initiate your Directory where the code is present 
```
terraform init
```

Do a Plan to see all the resources it will create 
```
terraform plan -auto-approve
```

Apply the Plan 
```
terraform apply -auto-approve
```

Once Setup is Verified, you can destroy the setup 
```
terraform destroy 
```
