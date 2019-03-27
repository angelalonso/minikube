#!/usr/bin/env bash

# STEPS:
# remove the default pi user
remove_pi_user() {
  sudo userdel pi
}
#  change SSH Port
#  avoid SSH as root
#  avoid SSH with password
ssh_tweak() {
  sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig
  promptValue "Enter your desired SSH PORT"
  SSHPORT=$val
  sudo sed -i 's/#Port 22/Port '$SSHPORT'/g' /etc/ssh/sshd_config
  # https://www.cyberciti.biz/faq/how-to-disable-ssh-password-login-on-linux/
  sudo sed -i 's/#PermitRootLogin .*/PermitRootLogin no/g' /etc/ssh/sshd_config
  sudo sed -i 's/#ChallengeResponseAuthentication .*/ChallengeResponseAuthentication no/g' /etc/ssh/sshd_config
  sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/g' /etc/ssh/sshd_config
  sudo sed -i 's/UsePAM yes/UsePAM no/g' /etc/ssh/sshd_config
  sudo systemctl restart sshd
}

#  generic function to ask for user interaction
promptValue() {
 read -p "$1"": " val
}

# IPTables

remove_pi_user
ssh_tweak
