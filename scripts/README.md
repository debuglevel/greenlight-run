# Helpers

## Running automatic updates

```
sudo ln -s $(pwd)/scripts/deploy.sh /usr/local/bin/greenlight-deploy
sudo cp $(pwd)/scripts/greenlight-auto-deployer.service /etc/systemd/system/greenlight-auto-deployer.service
sudo cp $(pwd)/scripts/greenlight-auto-deployer.timer /etc/systemd/system/greenlight-auto-deployer.timer
sudo systemctl daemon-reload
sudo systemctl enable greenlight-auto-deployer.service
sudo systemctl enable greenlight-auto-deployer.timer
sudo systemctl start greenlight-auto-deployer.timer
```
