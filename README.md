# Cardano Fast Deploy tools

Attention! Not all scripts need to be executed directly. Some of them are auxiliary. A more convenient shell for working with them will be written later.

## Instructions:
### Preparing for work:

Open the conf.json file and specify:
* The path to the directory where the environment should be deployed;
* Server's IP address;
* Software versions, port numbers, etc. for the required networks;
* You can add your own networks if needed;
* Remove unnecessary software from the configuration of required networks; 
* Make sure that the scripts have permission to execute!
* chmod +x ./* will grant it if necessary;

You can call scripts like `./software_deploy.sh <network_name>` or just `software_deploy.sh`

### Software installation & configuration:
* `software_deploy.sh [<network>]`
* `software_config.sh [<network>]`
* Then you can find your config files here: `/cardano_path_from_config/networks/<network>/config/`
* In order to switch the software version, just switch it in `conf.json` file and then launch run deploy again;

### Run it!
* there are run-scripts like `run_node.sh`, just launch it :)
* If you want to omit your IP, add --no-ip flag;
* Use `check_sync.sh` to check your sync state;

### Stake Pool Registration:
* Create wallet with `wallet_create.sh` or `wallet_restore.sh` command;
* Check your address and funds with `get_utxo.sh`
* Fund it if needed;
* Register your stake key with `reg_stake_key.sh`
* Create pool's cold keys with: `gen_pool_keys.sh`
* Create Pool Cert with: `gen_pool_cert.sh`
* Register Pool Cert with: `reg_pool_cert.sh`
* Create/update KES keys and opcert with: `gen_kes.sh`

Then launch your node with `run_pool.sh` instead of `run_node.sh`
In order to change your pool's parameters, just run `gen_pool_cert.sh` and `reg_pool_cert.sh` again;


There are also runners for cardano-db-sync and submit api.
Also you can use `manage-dbsync.sh` wrapper of original db-sync-tool.
