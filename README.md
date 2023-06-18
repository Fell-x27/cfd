# CFD - Cardano Fast Deployment
Your toolkit for quick and convenient management of your Cardano software.
Powered by MDS pool.



## Quick Start
**Installation**
```bash
git clone https://github.com/Fell-x27/cfd.git
cd ./cfd
chmod +x ./cardano.sh
```
**Usage**
```bash
./cardano.sh
```
Then follow the instructions :)

That's enough to get acquainted with Cardano!

Installation and configuration of Cardano software happen automatically at the first launch.
Even the deployment of db-sync, which usually poses difficulties for beginners, will be simple and quick, thanks to the built-in wizard!



## CFD supports two modes:
* Interactive - run `./cardano.sh` and select the required menu items
* Command - call `./cardano.sh` immediately with the required items, for example:
    * Running a node in passive mode -  `./cardano.sh preprod run-software node-relay`
    * Jumping straight to the software selection menu - `./cardano.sh preprod run-software`
    * Jumping to the mode selection in a given network - `./cardano.sh preprod`

As you can see, you can even mix both approaches if it's more convenient for you.



## FAQ:
### **I want to adjust the configs for myself, how can I do that?**
In the CFD directory: networks->%network_name%->config are all the auxiliary files that may be useful to you;


### **Where is the blockchain, wallets, and all such other stored?**
In the CFD directory: networks->%network_name%->storage


### **I created a wallet, where are its keys stored?**
In the CFD directory: networks->%network_name%->keys, the same place where different keys for pool operation will be stored;


### **What is the pool folder for?**
Mainly, for storing certificates;


### **Where are the executable files stored?**
CFD: networks->%network_name%->bin


### **I accidentally deleted bin/config, what should I do?**
Nothing, these folders only contain symlinks to real files, CFD will restore them automatically at the next launch;


### **Are the wallet/pool keys encrypted?**
Currently, like most console solutions, they are not. You must guard them carefully.


### **What is the cdf/software folder for?**
This folder contains the software and current configuration files for different networks, please do not touch this folder without an extreme need, it is 100% service;


### **There is an update for cardano-%softwareName%, how can I install it?**
There is a conf.json file next to cardano.sh:
* open it;
* find the "networks" section
* find the software you need
* find the "version" section
* write the new version

If the software requires new additional files (for example, configs), add the following to the above:
* find the "general" section
* find the "software" section
* find the software you need
* find the "required-files" section
* write the required file
* then, in the section where you set the version, also find "required-files"
* write your file there according to the example of the existing ones:
"filename": "instruction"

The instructions for obtaining the file are of different types: 
1) "d url" - download a file from a direct link in url
Example: "d https://hydra.iohk.io/job/Cardano/cardano-node/cardano-deployment/latest-finished/download/1/testnet-config.json"
2) "g %softwareName%" - get a file from a local machine, %softwareName% - the name of the software from which to take the file, which should already be installed in the system.
3) If there is no instruction, the script will try to get the file from the installed software.


## **What is the CFD features?**
* Bash only;
* Automatic installation of software;
* Automatic configuration of software;
* Automated pool management;
* Automatic handling of configuration files;
* Support for multiple networks at the same time;
* Convenient switching of software versions;
* Deployment of Cardano infrastructure "in one command";
* Compatibility with systemctl and similar systems;
* No untrusted external dependencies;
* Lightweight;

