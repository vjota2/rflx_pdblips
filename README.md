# rflx_pdblips
This resource adds configurable player blips onto your FiveM server with ESX framework!

## Requirements
- [es_extended v1.x](https://github.com/esx-framework/es_extended/tree/v1-final)
- __Brain__
### Optional
- Baseevents !with client side event!
- [mysql-async](https://github.com/brouznouf/fivem-mysql-async) when using character names

## Forum thread with showcase
https://forum.cfx.re/t/free-esx-emergency-job-blips-onesync-infinity/2794233

## Tutorials
### Duty implementation
**Onduty** can be setted by:
```
exports['rflx_pdblips']:goOnDuty()

or

TriggerEvent('rflx_pdblips:goOnDuty')
```

**Offduty** can be setted by:
```
exports['rflx_pdblips']:goOffDuty()

or

TriggerEvent('rflx_pdblips:goOffDuty')
```
Or even **toggling is possible**
```
TriggerEvent('rflx_pdblips:toggleDuty, onDutyBoolean) -- true or false
```

**More tutorials will be added upon requests!**
