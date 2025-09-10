# BLOCKCHAIN UPGRADE TIME ESTIMATOR<br>by AviaOne.com 
This script is working perfectly with all blockchains from Cosmos Ecosytem, we did not test it from others ecosystems...

## We took the AtomOne mainnet as an example to go up to block 5,000,000 and compared our script with Mintscan and Ping.pub explorer.


|   EXPLORER                  |        date             |         Estimated Time        |         Difference with our script        |
|---------------------|----------------------------------------|---------------------|---------------------|
Our script | 8 days 20 hours 23 minutes 49 seconds | 18 Sep 2025 22:34:14 | __________ 
Mintscan| 8 days 20 hours 33 minutes 18 seconds| 18 Sep 2025 22:42:09 | 9 minutes, 29 secondes 
Ping.pub| 9 days 2 hours 28 minutes 43 seconds | 19 Sep 2025 06:51:52 | <b>6 heures</b>, 4 minutes et 54 secondes 

## ping.pub has +6 hours extra compared to our script and Mintscan !
Screenshots are available below to help you clear up any doubts!

# How to use this script to estimate time ?
This script will dynamically estimate the number of blocks produced every 24 hours and provide a more accurate time estimate with this method.
## Install this script inside your server.
Create the folder.
```sh
mkdir -p $HOME/scripts/blockchain_upgrade_time_estimator/
```
Install the script inside the folder.
```sh
wget -O calcutate_update_time_blocks.sh https://raw.githubusercontent.com/aviaone/scripts/main/blockchain_upgrade_time_estimator/calcutate_update_time_blocks.sh
```
## Add your personalized settings
![image](https://github.com/AviaOne/pictures/blob/main/screenshot.2025-09-10%20(6).jpg?raw=true)

## Give the permission to your file.
```sh
chmod +x calcutate_update_time_blocks.sh
```

## add packages/ dependency if it's not done already.
```sh
sudo apt install -y curl jq bc
```
curl
Role: Performs HTTP requests to blockchain RPC endpoints

jq
Role: Parse and manipulate JSON data returned by blockchain APIs

bc
Role: Command-line calculator for precise mathematical calculations

## Now test it :rocket:
```sh
bash calcutate_update_time_blocks.sh
```
## You will see similar result :
![image](https://github.com/AviaOne/pictures/blob/main/screenshot.2025-09-10%20(4).jpg?raw=true)

## You now have a reliable estimate time 👍

### Mintscan result that we refer above to make this comparison
![image](https://github.com/AviaOne/pictures/blob/main/screenshot.2025-09-10.jpg?raw=true)

### Ping.pub explorer result that we refer above to make this comparison
![image](https://github.com/AviaOne/pictures/blob/main/screenshot.2025-09-10%20(5).jpg?raw=true)
