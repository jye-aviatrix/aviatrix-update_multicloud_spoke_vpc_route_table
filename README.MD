# What does the script solve
This PowerShell/Python script is indented to solve following problem:
1. When new subnet/route table added to existing VPC, the route table won't automatically be updated point to Aviatrix Spoke Gateway.
2. The normal procedure is to detach the Spoke Gateway from Transit Gateway, then re-attach the Spoke Gateway to Transit Gateway, this could cause an outage for the workload running on the VPC when it need to reach resources outside of VPC
3. The script is intended to perform following
    - Check and update VPC CIDR (in case new address space is added to existing VPC)
    - Check for newly added subnet and associated route table, then update the route table to point to Spoke Gateway, this is done without detach/attach.

# Usage
- Create new subnet
- Create new route table and populate endpoint routes etc when necessory.
- Associate new route table with the new subnet created.
- Modify config.json to indicate which Spoke Gateway's VPC route table need to be updated
- Make sure following environment variables are set
    - AVIATRIX_CONTROLLER_IP
    - AVIATRIX_USERNAME
    - AVIATRIX_PASSWORD
- The provided credential need to have write permission to the Access Account for the Spoke Gateway

## Run in PowerShell
- If you prefer PowerShell
    - Run PowerShell (Tested in PowerShell Core 7.4.6, will not work in PowerShell 5)
    - Load PowerShell module by running
        ```import-Module .\main.psm1 -force```
    - Run PowerShell command:
        ```Update-SpokeRouteTable```

- Example1
Spoke1 VPC added CIDR range '10.10.11.0/24' and '10.10.12.0/24'
Spoke1 VPC added subnet1/rt1 (rtb-094020a3d1c80a926), subnet2/rt2 (rtb-0cf323c16b57de33a)
After ran ```Update-SpokeRouteTable```

    ```
    Gateway spoke1 real VPC CIDRs changed to ['10.10.10.0/24', '10.10.11.0/24', '10.10.12.0/24'] successfully.
    Success to add VPC/VNet route tables ['rtb-094020a3d1c80a926', 'rtb-0cf323c16b57de33a'] and delete route tables [].
    ```

- Example2
When nothing need to be updated, but run ```Update-SpokeRouteTable``` anyway

    ```
    Real VPC CIDR not changed. Nothing to update.
    [AVXERR-TRANSIT-EDIT-0052] VPC/VNet route tables not changed. Nothing to update
    ```

- Example3
When route table rt1 (rtb-094020a3d1c80a926) disassociated from subnet1, then removed non-local routes, then the route table was deleted, then run ```Update-SpokeRouteTable```
    ```
    Real VPC CIDR not changed. Nothing to update.
    Success to add VPC/VNet route tables [] and delete route tables ['rtb-094020a3d1c80a926'].
    ```
Route table must be deleted to trigger above message, dis-associate route table from subnet won't be sufficient.


## Run in Python
- If you prefer python
    - Tested in Python 3.12.3
    - Run following command:
        ```python3 update-route-table.py```

# Note
- Out of band changes to Route Table will not be touched by the script.
- The script is unable to select which route table to update.