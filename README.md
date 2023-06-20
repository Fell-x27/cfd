# CFD - Cardano Fast Deployment tool
Your toolkit for quick and convenient management of your Cardano software.

❤️ Powered by *MDS* pool. ❤️



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

CFD will help you to:
1) Automatically install, configure and run Cardano software;
2) Monitor the synchronization of your node;
3) Automatically ensure the connectivity of different components;
4) Create/recover a mnemonic wallet and check its balance;
5) Automate the creation and maintenance of a staking pool (including related transactions);
6) Automatically track changes in configs between software versions and merge them, preserving user edits;
7) Even launching `db-sync` will seem easy to you!
8) The built-in smart wrapper over `cardano-cli` will handle situations where a socket or magic needs to be inserted, no headaches!



## CFD supports two modes:
* Interactive - run `./cardano.sh` and select the required menu items
* Command - call `./cardano.sh` immediately with the required items, for example:
    * Running a node in passive mode -  `./cardano.sh preprod run-software node-relay`
    * Jumping straight to the software selection menu - `./cardano.sh preprod run-software`
    * Jumping to the mode selection in a given network - `./cardano.sh preprod`

As you can see, you can even mix both approaches if it's more convenient for you.



## FAQ:
### **I want to adjust the configs for myself, how can I do that?**
In the CFD directory: `networks->%network_name%->config` are all the auxiliary files that may be useful to you;


### **Where is the blockchain, wallets, and all such other stored?**
In the CFD directory: `networks->%network_name%->storage`


### **I created a wallet, where are its keys stored?**
In the CFD directory: `networks->%network_name%->keys`, the same place where different keys for pool operation will be stored;


### **What is the `pool` folder for?**
Mainly, for storing certificates;


### **Where are the executable files stored?**
`cfd/networks->%network_name%->bin`


### **I accidentally deleted `bin`/`config`, what should I do?**
Nothing, these folders only contain symlinks to real files, CFD will restore them automatically at the next launch;


### **Are the wallet/pool keys encrypted?**
Currently, like most console solutions, they are not. You must guard them carefully.


### **What is the `cfd/software` folder for?**
This folder contains the software and current configuration files for different networks, please do not touch this folder without an extreme need, it is 100% service;

### What to do if the software configuration structure has changed and I already had custom parameters written?
You don't need to do anything, CFD will compare the configs itself, describe the changes noticed to you, transfer your changes to the new version, merge the files, provide a report of the work done, and then offer to familiarize yourself with the final version of the file in interactive mode.


https://github.com/Fell-x27/cfd/assets/18358207/809d20a3-9351-4dc1-8b55-d0e533b83e39



### Which software is supported out-of-the-box?
* cardano-node (+ cardano-submit-api)
* cardano-db-sync
* cardano-wallet
* cardano-addresses

### **There is an update for cardano-%softwareName%, how can I install it?**
There is a conf.json file next to cardano.sh:
1) open it;
2) find the "networks" section
3) find the software you need
4) find the "version" section
5) write the new version

If the software requires new additional files (for example, configs), add the following to the above:
1) find the "general" section
2) find the "software" section
3) find the software you need
4) find the "required-files" section
5) write the required file
6)  then, in the section where you set the version, also find "required-files"
7)  write your file there according to the example of the existing ones:
   "filename": "instruction"

The instructions for obtaining a file can be of different types:
* `"d url"` - download a file via a direct link in the url.
>For example: "d https://book.world.dev.cardano.org/environments/%/db-sync-config.json"
* `"dtgz url path strip"` - download an archive via the `url` link, extract the content from `path`, save it, reducing the path to the content to the `strip` level.
>For example: "dtgz https://github.com/input-output-hk/cardano-db-sync/archive/refs/tags/#.tar.gz cardano-db-sync-#/schema/ 1"
* `"p text chmod"` - create a file with the text content and assign it chmod access rights.
>For example: "p /var/run/postgresql:5432:%:: 0600"

Please note - the instructions contain the symbols `%` and `#`, these are placeholders for the `network name` and `software version` respectively. CFD will automatically insert the necessary data, you don't need to specify specific values there.

### Can I add additional networks?
Yes, simply add them to conf.json, following the examples already there.

### Can I create a staking pool?
Yes, of course. This is a standard option, just use the pool-manager in the menu.

### Can CFD be used in production?
CFD manages the entire infrastructure of the Medusa Wallet.

### What's the purpose of the `cli` option in the start menu?
This is a CFD wrapper over `cardano-cli` that performs all the same functions, but:

* It independently adds the path to the socket if needed;
* It independently adds network-magic if needed;
* In general, it's the same `cardano-cli`, but with enhanced comfort :)
  


https://github.com/Fell-x27/cfd/assets/18358207/8e5e39c7-6263-42ba-ace9-82b9baaadc2d



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


❤️ Powered by *MDS* pool. ❤️
