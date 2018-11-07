pragma solidity ^0.4.23;
import "./ERC20/StandardToken.sol";
import "./Ownable.sol";

contract BiLinkToken is StandardToken, Ownable {
	string public name = "BiLink"; 
	string public symbol = "BINK";
	uint256 public decimals = 18;
	uint256 public INITIAL_SUPPLY = 10000 * 10000 * (10 ** decimals);
	bool public mintingFinished = false;
	uint256 public totalMintableAmount;

	address public contractBalance;

	address public accountFoundation;
	address public accountCompany;
	address public accountPartnerBase;
	mapping (address => uint256) public lockedAccount2WithdrawTap;
	mapping (address => uint256) public lockedAccount2WithdrawedAmount;
	uint256 public lockStartTime;
	uint256 public lockEndTime;
	uint256 public releaseEndTime;
	uint256 public tapOfOne;
	uint256 public amountMinted;
	uint256 public lockTimeSpan;

	address[] public accountsCanShareProfit;//balance > 10000 * (10 ** decimals)
	uint256 public amountMinCanShareProfit;

	event Burn(address indexed burner, uint256 value);
	event Mint(address indexed to, uint256 amount);
	event MintFinished();

	constructor(address _owner, address _accountFoundation, address _accountCompany, address _accountPartnerBase) public 
		Ownable(_owner)
	{
		totalSupply_ = INITIAL_SUPPLY* 70/ 100;
		accountFoundation= _accountFoundation;
		accountCompany= _accountCompany;
		accountPartnerBase= _accountPartnerBase;

		lockStartTime= now;
		lockTimeSpan= 1 * 365 * 24 * 3600;
		lockEndTime= now+ lockTimeSpan;
		releaseEndTime= now+ 2 * lockTimeSpan;

		balances[accountCompany]= INITIAL_SUPPLY* 40/ 100;
		balances[accountFoundation]= INITIAL_SUPPLY* 10/ 100;
		balances[accountPartnerBase]= INITIAL_SUPPLY* 20/ 100;

		tapOfOne= (10 ** decimals)/ (lockTimeSpan);
		lockedAccount2WithdrawTap[accountCompany]= tapOfOne.mul(balances[accountCompany]);
		lockedAccount2WithdrawTap[accountPartnerBase]= tapOfOne.mul(balances[accountPartnerBase]);

		accountsCanShareProfit.push(accountCompany);
		accountsCanShareProfit.push(accountFoundation);
		accountsCanShareProfit.push(accountPartnerBase);

		amountMinCanShareProfit= 10000 * (10 ** decimals);
		totalMintableAmount= INITIAL_SUPPLY * 30/ 100;
	}

	function setMintAndBurnOwner (address _contractBalance) public onlyOwner {
		contractBalance= _contractBalance;
	}

	function burn(uint256 _amount) public {
		require(msg.sender== contractBalance);
		require(_amount <= balances[msg.sender]);

		balances[msg.sender] = balances[msg.sender].sub(_amount);
		totalSupply_ = totalSupply_.sub(_amount);
		emit Burn(msg.sender, _amount);
		emit Transfer(msg.sender, address(0), _amount);
	}

	function transferToPartnerAccount(address _partner, uint256 _amount) onlyOwner {
		require(balances[accountPartnerBase].sub(_amount) > 0);

		balances[_partner]= balances[_partner].add(_amount);
		balances[accountPartnerBase]= balances[accountPartnerBase].sub(_amount);

		lockedAccount2WithdrawTap[_partner]= tapOfOne.mul(balances[_partner]);

		if(balances[_partner].sub(_amount) < amountMinCanShareProfit&& balances[_partner] >= amountMinCanShareProfit)
			accountsCanShareProfit.push(_partner);
	}

	modifier canMint() {
		require(!mintingFinished);
		_;
	}

	modifier hasMintPermission() {
		require(msg.sender == contractBalance);
		_;
	}

	modifier canTransfer(address _from, address _to, uint256 _value)  {
        require(_from != accountFoundation&& (lockedAccount2WithdrawTap[_from] <= 0 || now >= releaseEndTime || (now >= lockEndTime && _value <= (lockedAccount2WithdrawTap[_from].mul(now.sub(lockStartTime))).sub(lockedAccount2WithdrawedAmount[_from]))));
        _;
    }

	function mintFinished() public constant returns (bool) {
		return mintingFinished;
	}

	function mint(address _to, uint256 _amount)
		hasMintPermission
		canMint
		public
		returns (bool)
	{
		uint256 _actualMintAmount= _amount.mul(totalMintableAmount- amountMinted).div(totalMintableAmount);
		if(amountMinted.add(_actualMintAmount) > totalMintableAmount) {
			finishMinting();
			return false;
		}
		else {
			amountMinted= amountMinted.add(_actualMintAmount);
			totalSupply_ = totalSupply_.add(_actualMintAmount);
			balances[_to] = balances[_to].add(_actualMintAmount);

			emit Mint(_to, _actualMintAmount);
			emit Transfer(address(0), _to, _actualMintAmount);
			return true;
		}
	}

	function finishMinting() canMint private returns (bool) {
		mintingFinished = true;
		emit MintFinished();
		return true;
	}

	function preTransfer(address _from, address _to, uint256 _value) private {
		if(lockedAccount2WithdrawTap[_from] > 0)
			lockedAccount2WithdrawedAmount[_from]= lockedAccount2WithdrawedAmount[_from].add(_value);

		if(balances[_from] >= amountMinCanShareProfit && balances[_from].sub(_value) < amountMinCanShareProfit) {
			for(uint256 i= 0; i< accountsCanShareProfit.length; i++) {
				if(accountsCanShareProfit[i]== _from) {
					if(i< accountsCanShareProfit.length- 1&& accountsCanShareProfit.length> 1)
						accountsCanShareProfit[i]= accountsCanShareProfit[accountsCanShareProfit.length- 1];
					delete accountsCanShareProfit[accountsCanShareProfit.length- 1];
					accountsCanShareProfit.length--;
					break;
				}
			}
		}

		if(balances[_to] < amountMinCanShareProfit&& balances[_to].add(_value) >= amountMinCanShareProfit) {
			accountsCanShareProfit.push(_to);
		}
	}

	function transfer(address _to, uint256 _value) public canTransfer(msg.sender, _to, _value) returns (bool) {
		preTransfer(msg.sender, _to, _value);

        return super.transfer(_to, _value);
    }

    function transferFrom(address _from, address _to, uint256 _value) public canTransfer(_from, _to, _value) returns (bool) {
		preTransfer(_from, _to, _value);

        return super.transferFrom(_from, _to, _value);
    }

    function approve(address _spender, uint256 _value) public canTransfer(msg.sender, _spender, _value) returns (bool) {
        return super.approve(_spender,_value);
    }

	function getCanShareProfitAccounts() public constant returns (address[]) {
		return accountsCanShareProfit;
	}
}