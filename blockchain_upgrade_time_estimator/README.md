# BLOCKCHAIN UPGRADE TIME ESTIMATOR<br>by AviaOne.com 
## Some explorer estimate block time with a fix value of 10,000 blocks per 24 hours
## Ping.pub explorer works like this, correct me if I'm wrong

## This script will estimate the time dynamically, to provide more precision, it will search for a time per second and per 24 hours

|                     | Dynamic Script (Your Script)             | Static Script (Fixed 10,000 Blocks)                 |
|---------------------|----------------------------------------|-----------------------------------------------------|
| Average block time  | 5.685 seconds<br>(calculated over 15,197 blocks) | 5.9 seconds<br>(fixed, assumed over 10,000 blocks)     |
| Estimated total time| 568,500 seconds<br>= 6 days 13 hours 35 min| 590,000 seconds<br>= 6 days 19 hours 26 min             |
| Difference          | —                                      | +21,500 seconds<br>= +5 hours 51 minutes                 |

<h2><span style="color: red;">The difference is huge over 100,000 blocks, with an inaccuracy of 5 hours and 51 minutes</span></h2>
