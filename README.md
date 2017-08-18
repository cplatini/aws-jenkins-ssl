The user_data_jenkins.sh is used for install and configuring jenkins to
use ssl auth, using nginx as a reverse_proxy. 

Copy the contents of the script, and paste into the user_data portion while
standing up Amazon Linux, Red Hat or CentOS EC2 instance.

To access jenkins on the newly created server, it must associated with an ELB.
