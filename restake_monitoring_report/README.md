 _Thanks to [MAXZONDER](https://github.com/maxzonder/mzscripts/tree/main/restake_report)_
This is a fork with improvements

# REStake Monitoring Script with Telegram Notifications
## _by AviaOne.com_

# Install
## Download to your server
```sh
mkdir -p $HOME/scripts/restake_monitoring_report && cd $HOME/scripts/restake_monitoring_report
```
```sh
wget -O restake_report.sh https://raw.githubusercontent.com/aviaone/scripts/main/restake_monitoring_report/restake_report.sh
wget -O restake_report.ini https://raw.githubusercontent.com/aviaone/scripts/main/restake_monitoring_report/restake_report.ini
```
## Open "restake_report.ini" and add your personnal information

| Your information | Ligne |
| ------ | ------ |
| Your telegram account id | TG_CHAT_ID="100123456789...." |
| Your telegram HTTP API | TG_TOKEN="123456789:ABCDEF..." |
| Alert if bot balance < 10 TOKENS | BALANCE_ALERT="1" |
| List of chains with denom 10^18 | ETH_CHAINS="Dymension Fetch.ai Evmos Canto" |

## Open "restake_report.sh" and choose how to start Restake
Choose if your Restake is working with "Services" or directly with NPM

IF Restake is working directly with NPM use :
```sh
cd restake
npm run autostake |
```

IF Restake is working with SERVICES  /etc/systemd/system use :
```sh
journalctl -u restake --since today -o cat --no-pager |
```

## Give the permission to your file
```sh
chmod +x /restake_monitoring_report.*
```
## Now test it
```sh
bash restake_report.sh
```
## Add Crontab to start this script automaticly
[How to Create and Set Up a Cron Job in Linux](https://phoenixnap.com/kb/set-up-cron-job-linux)

# This is the result displayed directly in your Telegram
![image](https://github.com/AviaOne/pictures/blob/main/screenshot.2025-09-09%20(6).jpg?raw=true)

## Error are displayed like this
![image](https://github.com/AviaOne/pictures/blob/main/screenshot.2025-09-09%20(4).jpg?raw=true)
![image](https://github.com/AviaOne/pictures/blob/main/screenshot.2025-09-09%20(3).jpg?raw=true)
