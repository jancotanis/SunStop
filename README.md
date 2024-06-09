# SunStop
Script to check dynamic hour energy prices and turn invertor off incase of negative pricing.

# GrowattHistory
Script to update PvOutput with first inverter settings. Currently not working for multiple inverters.

# Inverter
Both scripts are tested with MOD9000TL3-x

# Configuration
Use the following environment variables to configure the apps.
Tibber is used to get prices for SunStup and needs an access token. Growatt API is access using you credentials for https://server.growatt.com

For GrowattHistory upload to PVOut, and API key can be generated under settings. Together with the system id data can be uploaded.

```
TIBBER_ACCESS_TOKEN=<tibber token>
GROWATT_USERNAME=<server.growatt.com user>
GROWATT_PASSWORD=<server.growatt.com password>
PV_SYSTEM_ID=<system id>
PV_API_KEY=<API key>
```
