// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {Token} from "./Token.sol";

contract Factory {
    uint256 public constant TARGET = 3 ether;
    uint256 public constant TOKEN_LIMIT = 500_000 ether;
    uint256 public immutable fee;
    address public owner;

    address[] public tokens;
    uint256 public totalTokens;
    mapping(address => TokenSale) public tokenToSale;

    struct TokenSale{
        address token;
        string name;
        address creator;
        uint256 sold;
        uint256 raised;
        bool isOpen;
    }

    event Created(address indexed token);
    event Buy(address indexed token, uint256 amount);

    constructor(uint256 _fee){
        fee = _fee;
        owner = msg.sender;
    }

    function getTokenSale(uint256 _index) public view returns (TokenSale memory){
        return tokenToSale[tokens[_index]];
    }

    function getCost(uint256 _sold) public pure returns (uint256){
        uint256 floor = 0.0001 ether;
        uint256 step = 0.0001 ether;
        uint increment = 10000 ether;

        uint256 cost = (step * (_sold / increment)) + floor;
        return cost;
    }

    function create(string memory _name, string memory _symbol) external payable {
        // Making sure the fee is correct
        require(msg.value >= fee, "Factory: Not enough amount");

        //Cerate a new token
        Token token = new Token(msg.sender, _name, _symbol, 1_000_000 ether);

        //Save the token for later use
        tokens.push(address(token));

        totalTokens++;

        // List the token for sale
        TokenSale memory sale = TokenSale(
            address(token),
            _name,
            msg.sender,
            0,
            0,
            true
        );
        tokenToSale[address(token)] = sale;

        //Tell people its live
        emit Created(address(token));
    }

    function buy(address _token, uint256 _amount) external payable {
        TokenSale storage sale = tokenToSale[_token];
        // Check conditions
        require(sale.isOpen == true, "Factory: Buying closed.");
        require(_amount >= 1 ether, "Factory: Amount too low");
        require(_amount <= 10000 ether, "Factory: Amount exceeded");

        //Calculate the price of 1 token based upon total bought.
        uint256 cost = getCost(sale.sold);

        uint256 price = cost * (_amount / 10 ** 18);

        //Make sure enough eth is sent
        require(msg.value >= price, "Factory: Insufficient ETH received,");

        //Update the sales
        sale.sold += _amount;
        sale.raised += price;

        //Make sure fund raising gole isn't met
        if(sale.sold >= TOKEN_LIMIT  || sale.raised >= TARGET) {
            sale.isOpen = false;
        }
        
        Token(_token).transfer(msg.sender, _amount);

        //EMit an event
        emit Buy(_token, _amount);
    }

    function deposit(address _token) external {
        //The remaining token balance and the ETH raised
        //would go into a liquidity pool like Uniswap V3 etc.abi

        //For Simplicity we will transfer the token back to the creator

        Token token = Token(_token);
        TokenSale memory sale = tokenToSale[_token];

        require(sale.isOpen == false, "Factory: Target not reached");

        //Transfer tokens
        token.transfer(sale.creator, token.balanceOf(address(this)));

        //Transfer ETH raised
        (bool success, ) = payable(sale.creator).call{value: sale.raised}("");
        require(success, "factory: ETH transfer failed");
    }

    function withdraw(uint256 _amount) external {
        require(msg.sender == owner, "Factory: Not owner");

        (bool success, ) = payable(owner).call{value: _amount}("");
        require(success, "Factory: ETH transfer failed");
    }
}
