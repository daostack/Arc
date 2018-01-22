# *contract* UController ([source](https://github.com/daostack/daostack/tree/master/./contracts/controller/UController.sol))
*Code deposit cost: **less than 2864000 gas.***

*Execution cost: **less than 3126 gas.***

*Total deploy cost(deposit + execution): **less than 2867126 gas.***

> Universal Controller contract


## Reference
- [Constructors](#constructors)
    - [UController()](#constructor-ucontroller)
- [Events](#events)
    - [ExternalTokenTransfer](#event-externaltokentransfer)
    - [UpgradeController](#event-upgradecontroller)
    - [ExternalTokenTransferFrom](#event-externaltokentransferfrom)
    - [RegisterScheme](#event-registerscheme)
    - [RemoveGlobalConstraint](#event-removeglobalconstraint)
    - [SendEther](#event-sendether)
    - [UnregisterScheme](#event-unregisterscheme)
    - [MintTokens](#event-minttokens)
    - [MintReputation](#event-mintreputation)
    - [GenericAction](#event-genericaction)
    - [ExternalTokenIncreaseApproval](#event-externaltokenincreaseapproval)
    - [ExternalTokenDecreaseApproval](#event-externaltokendecreaseapproval)
    - [AddGlobalConstraint](#event-addglobalconstraint)
- [Fallback](#fallback)
- [Functions](#functions)
    - [mintReputation](#function-mintreputation)
    - [unregisterScheme](#function-unregisterscheme)
    - [upgradeController](#function-upgradecontroller)
    - [unregisterSelf](#function-unregisterself)
    - [getSchemePermissions](#function-getschemepermissions)
    - [newControllers](#function-newcontrollers)
    - [sendEther](#function-sendether)
    - [registerScheme](#function-registerscheme)
    - [newOrganization](#function-neworganization)
    - [removeGlobalConstraint](#function-removeglobalconstraint)
    - [externalTokenTransfer](#function-externaltokentransfer)
    - [getSchemeParameters](#function-getschemeparameters)
    - [isGlobalConstraintRegistered](#function-isglobalconstraintregistered)
    - [isSchemeRegistered](#function-isschemeregistered)
    - [mintTokens](#function-minttokens)
    - [globalConstraintsCount](#function-globalconstraintscount)
    - [genericAction](#function-genericaction)
    - [externalTokenTransferFrom](#function-externaltokentransferfrom)
    - [externalTokenIncreaseApproval](#function-externaltokenincreaseapproval)
    - [externalTokenDecreaseApproval](#function-externaltokendecreaseapproval)
    - [addGlobalConstraint](#function-addglobalconstraint)
### Constructors
### *constructor* UController()

*Execution cost: **No bound available.***

**nonpayable**

*Params:*
*Nothing*


### Events
### *event* ExternalTokenTransfer
*Params:*
1. **_sender** *of type address*
2. **_externalToken** *of type address*
3. **_to** *of type address*
4. **_value** *of type uint256*


### *event* UpgradeController
*Params:*
1. **_oldController** *of type address*
2. **_newController** *of type address*
3. **_avatar** *of type address*


### *event* ExternalTokenTransferFrom
*Params:*
1. **_sender** *of type address*
2. **_externalToken** *of type address*
3. **_from** *of type address*
4. **_to** *of type address*
5. **_value** *of type uint256*


### *event* RegisterScheme
*Params:*
1. **_sender** *of type address*
2. **_scheme** *of type address*
3. **_avatar** *of type address*


### *event* RemoveGlobalConstraint
*Params:*
1. **_globalConstraint** *of type address*
2. **_index** *of type uint256*


### *event* SendEther
*Params:*
1. **_sender** *of type address*
2. **_amountInWei** *of type uint256*
3. **_to** *of type address*


### *event* UnregisterScheme
*Params:*
1. **_sender** *of type address*
2. **_scheme** *of type address*
3. **_avatar** *of type address*


### *event* MintTokens
*Params:*
1. **_sender** *of type address*
2. **_beneficiary** *of type address*
3. **_amount** *of type uint256*
4. **_avatar** *of type address*


### *event* MintReputation
*Params:*
1. **_sender** *of type address*
2. **_beneficiary** *of type address*
3. **_amount** *of type int256*
4. **_avatar** *of type address*


### *event* GenericAction
*Params:*
1. **_sender** *of type address*
2. **_params** *of type bytes32[]*


### *event* ExternalTokenIncreaseApproval
*Params:*
1. **_sender** *of type address*
2. **_externalToken** *of type address*
3. **_spender** *of type address*
4. **_value** *of type uint256*


### *event* ExternalTokenDecreaseApproval
*Params:*
1. **_sender** *of type address*
2. **_externalToken** *of type address*
3. **_spender** *of type address*
4. **_value** *of type uint256*


### *event* AddGlobalConstraint
*Params:*
1. **_globalConstraint** *of type address*
2. **_params** *of type bytes32*


### Fallback
*Nothing*
### Functions
### *function* mintReputation

*Execution cost: **No bound available.***

**nonpayable**

*Inputs:*
1. **_amount** *of type int256*
2. **_beneficiary** *of type address*
3. **_avatar** *of type address*

*Returns:*
1. **unnamed** *of type bool*


### *function* unregisterScheme

*Execution cost: **No bound available.***

**nonpayable**

*Inputs:*
1. **_scheme** *of type address*
2. **_avatar** *of type address*

*Returns:*
1. **unnamed** *of type bool*


### *function* upgradeController

*Execution cost: **No bound available.***

**nonpayable**

*Inputs:*
1. **_newController** *of type address*
2. **_avatar** *of type address*

*Returns:*
1. **unnamed** *of type bool*


### *function* unregisterSelf
> unregister the caller's scheme

*Execution cost: **less than 28509 gas.***

**nonpayable**

*Inputs:*
1. **_avatar** *of type address- the organization avatar.

bool which represents a success

### *function* getSchemePermissions

*Execution cost: **No bound available.***

**constant | view**

*Inputs:*
1. **_scheme** *of type address*
2. **_avatar** *of type address*

*Returns:*
1. **unnamed** *of type bytes4*


### *function* newControllers

*Execution cost: **less than 824 gas.***

**constant | view**

*Inputs:*
1. **unnamed** *of type address*

*Returns:*
1. **unnamed** *of type address*


### *function* sendEther

*Execution cost: **No bound available.***

**nonpayable**

*Inputs:*
1. **_amountInWei** *of type uint256*
2. **_to** *of type address*
3. **_avatar** *of type address*

*Returns:*
1. **unnamed** *of type bool*


### *function* registerScheme

*Execution cost: **No bound available.***

**nonpayable**

*Inputs:*
1. **_scheme** *of type address*
2. **_paramsHash** *of type bytes32*
3. **_permissions** *of type bytes4*
4. **_avatar** *of type address*

*Returns:*
1. **unnamed** *of type bool*


### *function* newOrganization
> newOrganization set up a new organization with default genesisScheme.

*Execution cost: **No bound available.***

**nonpayable**

*Inputs:*
1. **_avatar** *of type address- the organization avatar

*Returns:*
*Nothing*


### *function* removeGlobalConstraint

*Execution cost: **No bound available.***

**nonpayable**

*Inputs:*
1. **_globalConstraint** *of type address*
2. **_avatar** *of type address*

*Returns:*
1. **unnamed** *of type bool*


### *function* externalTokenTransfer

*Execution cost: **No bound available.***

**nonpayable**

*Inputs:*
1. **_externalToken** *of type address*
2. **_to** *of type address*
3. **_value** *of type uint256*
4. **_avatar** *of type address*

*Returns:*
1. **unnamed** *of type bool*


### *function* getSchemeParameters

*Execution cost: **No bound available.***

**constant | view**

*Inputs:*
1. **_scheme** *of type address*
2. **_avatar** *of type address*

*Returns:*
1. **unnamed** *of type bytes32*


### *function* isGlobalConstraintRegistered

*Execution cost: **No bound available.***

**constant | view**

*Inputs:*
1. **_globalConstraint** *of type address*
2. **_avatar** *of type address*

*Returns:*
1. **unnamed** *of type bool*


### *function* isSchemeRegistered

*Execution cost: **No bound available.***

**constant | view**

*Inputs:*
1. **_scheme** *of type address*
2. **_avatar** *of type address*

*Returns:*
1. **unnamed** *of type bool*


### *function* mintTokens

*Execution cost: **No bound available.***

**nonpayable**

*Inputs:*
1. **_amount** *of type uint256*
2. **_beneficiary** *of type address*
3. **_avatar** *of type address*

*Returns:*
1. **unnamed** *of type bool*


### *function* globalConstraintsCount

*Execution cost: **less than 909 gas.***

**constant | view**

*Inputs:*
1. **_avatar** *of type address*

*Returns:*
1. **unnamed** *of type uint256*


### *function* genericAction

*Execution cost: **No bound available.***

**nonpayable**

*Inputs:*
1. **_params** *of type bytes32[]*
2. **_avatar** *of type address*

*Returns:*
1. **unnamed** *of type bool*


### *function* externalTokenTransferFrom

*Execution cost: **No bound available.***

**nonpayable**

*Inputs:*
1. **_externalToken** *of type address*
2. **_from** *of type address*
3. **_to** *of type address*
4. **_value** *of type uint256*
5. **_avatar** *of type address*

*Returns:*
1. **unnamed** *of type bool*


### *function* externalTokenIncreaseApproval

*Execution cost: **No bound available.***

**nonpayable**

*Inputs:*
1. **_externalToken** *of type address*
2. **_spender** *of type address*
3. **_addedValue** *of type uint256*
4. **_avatar** *of type address*

*Returns:*
1. **unnamed** *of type bool*


### *function* externalTokenDecreaseApproval

*Execution cost: **No bound available.***

**nonpayable**

*Inputs:*
1. **_externalToken** *of type address*
2. **_spender** *of type address*
3. **_subtractedValue** *of type uint256*
4. **_avatar** *of type address*

*Returns:*
1. **unnamed** *of type bool*


### *function* addGlobalConstraint

*Execution cost: **No bound available.***

**nonpayable**

*Inputs:*
1. **_globalConstraint** *of type address*
2. **_params** *of type bytes32*
3. **_avatar** *of type address*

*Returns:*
1. **unnamed** *of type bool*

