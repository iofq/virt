# virsh
This project was created to streamline creating VMs across my local hardware with libvirt. Using premade OS images and cloud-init, we can easily spin up a machine in a state ready for Ansible to further configure. VNC is also enabled if needed.

## Usage:

 - obtain a .qcow2 image of your OS of choice and place it in `images/`
 - create or edit the file user-data
   - [Examples](https://cloudinit.readthedocs.io/en/latest/topics/examples.html)
   - at least a user and ssh key or password is needed to access the system

```bash
./virt-install.sh -h HOSTNAME -i IMAGE.qcow2
```

## Flags:
`-h HOSTNAME` - hostname of created machine. `HOSTNAME.qcow2` will be created in images/

`-i IMAGE` (optional) .qcow2 image to clone. If left out, `images/base.qcow2` will be tried.

`-r RAM` - (optional) Ram in MB to be allocated to the machine

`-c CPU` - (optional) Virtual CPUs to be allocated to the machine

## Config:
Configuration can be made by editing the `config` file. The defaults are set by the script and any changes will override them.
