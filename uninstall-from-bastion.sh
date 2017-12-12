set -x

# Elevate priviledges, retaining the environment.
sudo -E su

# Run the playbook.
ANSIBLE_HOST_KEY_CHECKING=False /usr/local/bin/ansible-playbook -i ./inventory.cfg ./openshift-ansible/playbooks/adhoc/uninstall.yml # uncomment for verbose! -vvv

