# BLOCKCHAIN UPGRADE TIME ESTIMATOR<br>by AviaOne.com 
This script is working perfectly with all blockchains from Cosmos Ecosytem, we did not test it from an others ecosystems...
## Some explorer estimate block time with a fix value of 10,000 blocks per 24 hours. 
Ping.pub explorer works like this, correct me if I'm wrong...

## This script will estimate the time dynamically, to provide more precision, it will search for a time per second and per 24 hours.

|                     | Dynamic Script (Your Script)             | Static Script (Fixed 10,000 Blocks)                 |
|---------------------|----------------------------------------|-----------------------------------------------------|
| Average block time  | 5.685 seconds<br>(calculated over 15,197 blocks) | 5.9 seconds<br>(fixed, assumed over 10,000 blocks)     |
| Estimated total time| 568,500 seconds<br>= 6 days 13 hours 35 min| 590,000 seconds<br>= 6 days 19 hours 26 min             |
| Difference          | —                                      | +21,500 seconds<br>= +5 hours 51 minutes                 |
###  The difference is huge over 100,000 blocks, with an inaccuracy of 5 hours and 51 minutes.

# How to use this script to estimate time dynamically?
## Install this script inside your server.
Create the folder.
```sh
mkdir -p $HOME/scripts/blockchain_upgrade_time_estimator/
```
Install the script inside the folder.
```sh
wget -O calcutate_update_time_blocks.sh https://raw.githubusercontent.com/aviaone/scripts/main/blockchain_upgrade_time_estimator/calcutate_update_time_blocks.sh
```
## Add your add your personalized settings
![image](https://github.com/AviaOne/pictures/blob/main/screenshot.2025-09-09%20(8).jpg?raw=true)

## Give the permission to your file.
```sh
chmod +x /calcutate_update_time_blocks.sh
```

## Now test it :rocket:
```sh
calcutate_update_time_blocks.sh
```
## You will see this result :
![image](https://github.com/AviaOne/pictures/blob/main/screenshot.2025-09-09%20(9).jpg?raw=true?raw=true)

## You now have a reliable estimate time
