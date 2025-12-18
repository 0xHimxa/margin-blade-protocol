// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';

contract Edge is ERC20{



////////////////
// ERRORS //
////////////////

error EDGEToken__AmountCantBeZero();



constructor(string memory name,string memory symbol)ERC20(name,symbol){}


modifier minimumChecks(uint256 _amount){

  if(_amount <= 0){
    revert EDGEToken__AmountCantBeZero();
  }
  _;


}



 function mint(address _to,uint256 _amount)external minimumChecks(_amount){


  _mint(_to,_amount);

 } 

 function burn(address _from,uint256 _amount)external minimumChecks(_amount){

  _burn(_from,_amount);

 }

    
}
