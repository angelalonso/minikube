#!/usr/bin/env bash

# STEPS:
#  update, upgrade, install tools
update_system() {
  sudo apt-get update && sudo apt-get upgrade
  sudo apt-get install vim git
}
#  create new user, give it admin access, add public key
add_user() {
  echo 
  echo "Before we start, make sure you have your SSH keypair ready at your local machine"
  echo '- you can generate one with: ssh-keygen -f filename -t rsa -b 4096 -C "your_email@example.com"'
  promptValue "Press Enter to continue"

  promptValue "Enter your user name"
  USER=$val
  sudo useradd -m -s /bin/bash $USER 
  sudo mkdir /home/$USER/.ssh 
  sudo touch /home/$USER/.ssh/authorized_keys 
  sudo chmod 600 /home/$USER/.ssh/authorized_keys 
  sudo chown -R $USER:$USER /home/$USER 

  sudo passwd $USER

  echo "Next you will be asked to add your public Key"
  echo 
  promptValue "Please look for it now and press <ENTER> when you are ready"
  sudo vi /home/$USER/.ssh/authorized_keys 
  
  echo "Next you have to add $USER to the sudo group"
  promptValue "Press Enter to continue"

  #sudo vigr
  sudo sed -i.orig 's/:pi/:pi,'$USER'/g' /etc/group
  sudo chown -R $USER. /home/$USER
  echo "Next you have to LOGOUT and LOGIN again with the user $USER"
  promptValue "Press Enter to continue"
  logoout
}

#  generic function to ask for user interaction
promptValue() {
 read -p "$1"": " val
}

# IPTables

update_system
add_user
