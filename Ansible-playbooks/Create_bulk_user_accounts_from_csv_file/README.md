# Create bulk user accounts from csv file

###### By Juan Manuel Payán / jpaybar

[st4rt.fr0m.scr4tch@gmail.com](mailto:st4rt.fr0m.scr4tch@gmail.com)

This playbook creates users in bulk from a .csv file, creates the "wheel" group
for those users and gives them "sudo" permission. The generic password is read
from a file encrypted with "ansible-vault", users will have to change the password
the first time they log in to the system.

Link:

https://www.redhat.com/sysadmin/ansible-create-users-csv

## Settings

- `vars/password.yml`: Encrypted file containing the password.
- `vars/variables.yml`: File containing the group to create.
- `files/sudoers_wheel.j2`: Jinja template for wheel group.
- `csv/username.csv`: The CSV file that contains the users' information.
- `create_user.yml`: Main playbook.

## Running this Playbook

Quickstart guide for those already familiar with Ansible:

### 1. Obtain the playbook

```shell
git clone https://github.com/jpaybar/ansible-playbooks.git
cd ansible-playbooks/Create_bulk_user_accounts_from_csv_file
```

### 2. Directory tree

```bash
.
├── create_user.yml
├── csv
│   └── username.csv
├── files
│   └── sudoers_wheel.j2
├── inventory_hosts
├── README.md
└── vars
    ├── password.yml
    └── variables.yml
```

### 3. Customize variable files and templates

```bash
nano vars/password.yml
```

```yml
$ANSIBLE_VAULT;1.1;AES256
34613338346335646534343536666639663232613364363262363231346637643666353163633662
6462633933316638623834326566643734343233626238650a336331643430653732653335356638
36373463353130363465333838373836393966393862363531393739303231643132333166366463
3866323465663438370a616136333232343731626634383063343139363165313462336461393434
30373435663034616261313734343939303335366365373165643636333939383738
```

```bash
nano vars/variables.yml
```

```yml
---
group: wheel
```

```bash
nano files/sudoers_wheel.j2
```

```jinja2
# Allow "sudo" to "wheel" group

%{{ group }} ALL=(ALL) NOPASSWD:ALL
```

```bash
nano csv/username.csv
```

```csv
Username,UID,First_name,Last_name,Groups
yozu00,2000,Yasujiro,Ozu,wheel
akurosawa01,2001,Akira,Kurosawa,wheel
kmizoguchi02,2002,Kenji,Mizoguchi,wheel
iinagaki03,2003,Iroshi,Inagaki,wheel
kshindo04,2004,Kaneto,Shindo,wheel
```

### 4. Encrypt `vars/password.yml` file

Run the following command and enter vault password:

```bash
ansible-vault encrypt password.yml
```

To edit the file in future use this command and provide the vault password:

```bash
ansible-vault edit password.yml
```

To view the file use this command and provide the vault password:

```bash
ansible-vault view password.yml
```

```yml
# Generic password for user accounts
password: "password"
```

To check the playbook syntax, run this command and provide the vault password:

```bash
ansible-playbook create_user.yml –syntax-check –ask-vault-pass
```

### 5. Run the Playbook

Run the following command if you have already exported your public key to remote nodes:

```bash
ansible-playbook -l [target] -i [inventory] create_user.yml --ask-vault-pass
```

In case you connect by username/password, run the following command:

```bash
ansible-playbook -l [target] -i [inventory] create_user.yml --ask-vault-pass -u [user] -k [ssh password]
```

### 6. Test the Playbook

Test by logging in to the managed nodes using the new user accounts. It will prompt to change the password after the logon.
