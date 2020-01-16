
./vsrx-aws deploy --region us-east-1 \
                  --key-name <key_name> \
                  --key-file <key-file> \
                  --vpc-id <vpc-id> \
                  --nic subnet-name=mgt-01,public-ip=auto \
                  --nic subnet-name=gw-01,public-ip=auto \
                  --profile default \
                  ami-06b424cccf70e6a94


