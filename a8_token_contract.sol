// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.0;

import "./ITRC20.sol";
import "./SafeMath.sol";

/**
 * @dev Implementation of the {ITRC20} interface.
 * @dev {ITRC20} 接口的實現。
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {TRC20Mintable}.
 * 此實現與代幣創建方式無關。這意味著必須在派生合約中使用 {_mint} 添加供應機制。
 * 對於通用機制，請參見 {TRC20Mintable}。
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-erc20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 * 提示：詳細說明請參見我們的指南
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of TRC20 applications.
 * 我們遵循了一般的 OpenZeppelin 指南：函數在失敗時會回滾而不是返回 `false`。
 * 這種行為仍然是常規的，不會與 TRC20 應用程序的期望相衝突。
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 * 此外，調用 {transferFrom} 時會發出 {Approval} 事件。
 * 這使應用程序僅通過監聽這些事件就能重建所有賬戶的授權額度。
 * 其他 EIP 實現可能不會發出這些事件，因為規範並不要求這樣做。
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {ITRC20-approve}.
 * 最後，添加了非標準的 {decreaseAllowance} 和 {increaseAllowance} 函數，
 * 以減輕設置授權額度時的已知問題。請參見 {ITRC20-approve}。
 */
contract TRC20 is ITRC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    using SafeMath for uint256;

    mapping (address => uint256) private _balances;

    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _totalSupply;

    address private _owner;

    // Reward system related variables
    // 獎勵系統相關變量
    uint256 private _transferCount;           // Total transfer count / 轉賬總次數
    uint256 private _currentRewardAmount;     // Current reward amount / 當前獎勵額度
    uint256 private constant INITIAL_REWARD = 500 * 10**18; // Initial reward 500 tokens / 初始獎勵500個代幣
    uint256 private constant HALVING_INTERVAL = 100000;     // Halving every 100,000 times / 10萬次減半
    bool private _rewardEnabled;              // Reward switch / 獎勵開關

    // Reward events / 獎勵事件
    event RewardGiven(address indexed recipient, uint256 amount, uint256 transferCount);
    event RewardHalved(uint256 newRewardAmount, uint256 transferCount);
    event RewardToggled(bool enabled);

    constructor (uint256 initialSupply) {
        _name = "A8 AI Ecosystem";
        _symbol = "A8";
        _decimals = 18;
        _owner = msg.sender;

        // Initialize reward system / 初始化獎勵系統
        _transferCount = 0;
        _currentRewardAmount = INITIAL_REWARD;
        _rewardEnabled = true;

        _mint(msg.sender, initialSupply * (10 ** uint256(decimals())));
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }

    // Modifier to restrict functions to owner only
    // 僅限所有者調用的修飾符
    modifier onlyOwner() {
        require(msg.sender == _owner, "TRC20: caller is not the owner");
        _;
    }

    /**
     * @dev See {ITRC20-totalSupply}.
     * @dev 參見 {ITRC20-totalSupply}。
     */
    function totalSupply() override public view returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {ITRC20-balanceOf}.
     * @dev 參見 {ITRC20-balanceOf}。
     */
    function balanceOf(address account) override public view returns (uint256) {
        return _balances[account];
    }

    /**
     * @dev See {ITRC20-transfer}.
     * @dev 參見 {ITRC20-transfer}。
     *
     * Requirements:
     * 要求：
     *
     * - `recipient` cannot be the zero address.
     * - `recipient` 不能是零地址。
     * - the caller must have a balance of at least `amount`.
     * - 調用者必須有至少 `amount` 的余額。
     */
    function transfer(address recipient, uint256 amount) override public returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev See {ITRC20-allowance}.
     * @dev 參見 {ITRC20-allowance}。
     */
    function allowance(address owner, address spender) override public view returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {ITRC20-approve}.
     * @dev 參見 {ITRC20-approve}。
     *
     * Requirements:
     * 要求：
     *
     * - `spender` cannot be the zero address.
     * - `spender` 不能是零地址。
     */
    function approve(address spender, uint256 value) override public returns (bool) {
        _approve(msg.sender, spender, value);
        return true;
    }

    /**
     * @dev See {ITRC20-transferFrom}.
     * @dev 參見 {ITRC20-transferFrom}。
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {TRC20};
     * 發出 {Approval} 事件以指示更新的授權額度。EIP 並不要求這樣做。
     * 請參見 {TRC20} 開頭的注釋；
     *
     * Requirements:
     * 要求：
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` 和 `recipient` 不能是零地址。
     * - `sender` must have a balance of at least `value`.
     * - `sender` 必須有至少 `value` 的余額。
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     * - 調用者必須有 `sender` 代幣的至少 `amount` 授權額度。
     */
    function transferFrom(address sender, address recipient, uint256 amount) override public returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     * @dev 原子性地增加調用者授予 `spender` 的授權額度。
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {ITRC20-approve}.
     * 這是 {approve} 的替代方案，可用作 {ITRC20-approve} 中描述問題的緩解措施。
     *
     * Emits an {Approval} event indicating the updated allowance.
     * 發出 {Approval} 事件以指示更新的授權額度。
     *
     * Requirements:
     * 要求：
     *
     * - `spender` cannot be the zero address.
     * - `spender` 不能是零地址。
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     * @dev 原子性地減少調用者授予 `spender` 的授權額度。
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {ITRC20-approve}.
     * 這是 {approve} 的替代方案，可用作 {ITRC20-approve} 中描述問題的緩解措施。
     *
     * Emits an {Approval} event indicating the updated allowance.
     * 發出 {Approval} 事件以指示更新的授權額度。
     *
     * Requirements:
     * 要求：
     *
     * - `spender` cannot be the zero address.
     * - `spender` 不能是零地址。
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     * - `spender` 必須有調用者的至少 `subtractedValue` 授權額度。
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     * @dev 將 `amount` 數量的代幣從 `sender` 轉移到 `recipient`。
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     * 這個內部函數相當於 {transfer}，可以用來實現自動代幣費用、削減機制等。
     *
     * Emits a {Transfer} event.
     * 發出 {Transfer} 事件。
     *
     * Requirements:
     * 要求：
     *
     * - `sender` cannot be the zero address.
     * - `sender` 不能是零地址。
     * - `recipient` cannot be the zero address.
     * - `recipient` 不能是零地址。
     * - `sender` must have a balance of at least `amount`.
     * - `sender` 必須有至少 `amount` 的余額。
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "TRC20: transfer from the zero address");
        require(recipient != address(0), "TRC20: transfer to the zero address");

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);

        // Process transfer reward / 處理轉賬獎勵
        _processTransferReward(recipient);
    }

    /**
     * @dev Process transfer reward logic
     * @dev 處理轉賬獎勵邏輯
     */
    function _processTransferReward(address recipient) internal {
        if (!_rewardEnabled || _currentRewardAmount == 0) {
            return;
        }

        // Increase transfer count / 增加轉賬次數
        _transferCount = _transferCount.add(1);

        // Check if halving is needed / 檢查是否需要減半
        if (_transferCount > 0 && _transferCount % HALVING_INTERVAL == 0) {
            _currentRewardAmount = _currentRewardAmount.div(2);
            emit RewardHalved(_currentRewardAmount, _transferCount);

            // If reward amount is less than 1 wei, set to 0 and stop rewarding
            // 如果獎勵額度已經小於1 wei，則設置為0，停止獎勵
            if (_currentRewardAmount < 1) {
                _currentRewardAmount = 0;
                _rewardEnabled = false;
                emit RewardToggled(false);
            }
        }

        // Give reward (ensure contract has sufficient balance)
        // 給予獎勵（需要確保合約有足夠余額）
        if (_balances[address(this)] >= _currentRewardAmount && _currentRewardAmount > 0) {
            _balances[address(this)] = _balances[address(this)].sub(_currentRewardAmount);
            _balances[recipient] = _balances[recipient].add(_currentRewardAmount);

            emit Transfer(address(this), recipient, _currentRewardAmount);
            emit RewardGiven(recipient, _currentRewardAmount, _transferCount);
        }
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     * @dev 創建 `amount` 數量的代幣並分配給 `account`，增加總供應量。
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     * 發出 {Transfer} 事件，其中 `from` 設置為零地址。
     *
     * Requirements
     * 要求
     *
     * - `to` cannot be the zero address.
     * - `to` 不能是零地址。
     */
    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "TRC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

     /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     * @dev 從 `account` 銷毀 `amount` 數量的代幣，減少總供應量。
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     * 發出 {Transfer} 事件，其中 `to` 設置為零地址。
     *
     * Requirements
     * 要求
     *
     * - `account` cannot be the zero address.
     * - `account` 不能是零地址。
     * - `account` must have at least `amount` tokens.
     * - `account` 必須有至少 `amount` 數量的代幣。
     */
    function _burn(address account, uint256 value) internal {
        require(account != address(0), "TRC20: burn from the zero address");

        _totalSupply = _totalSupply.sub(value);
        _balances[account] = _balances[account].sub(value);
        emit Transfer(account, address(0), value);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     * @dev 將 `amount` 設置為 `spender` 對 `owner` 代幣的授權額度。
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     * 這個內部函數相當於 `approve`，可以用來為某些子系統設置自動授權額度等。
     *
     * Emits an {Approval} event.
     * 發出 {Approval} 事件。
     *
     * Requirements:
     * 要求：
     *
     * - `owner` cannot be the zero address.
     * - `owner` 不能是零地址。
     * - `spender` cannot be the zero address.
     * - `spender` 不能是零地址。
     */
    function _approve(address owner, address spender, uint256 value) internal {
        require(owner != address(0), "TRC20: approve from the zero address");
        require(spender != address(0), "TRC20: approve to the zero address");

        _allowances[owner][spender] = value;
        emit Approval(owner, spender, value);
    }

    /**
     * @dev Destoys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     * @dev 從 `account` 銷毀 `amount` 數量的代幣。然後從調用者的授權額度中扣除 `amount`。
     *
     * See {_burn} and {_approve}.
     * 參見 {_burn} 和 {_approve}。
     */
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(account, msg.sender, _allowances[account][msg.sender].sub(amount));
    }

    // ==================== Reward System Management Functions ====================
    // ==================== 獎勵系統管理函數 ====================

    /**
     * @dev Get current transfer count
     * @dev 獲取當前轉賬次數
     */
    function getTransferCount() public view returns (uint256) {
        return _transferCount;
    }

    /**
     * @dev Get current reward amount
     * @dev 獲取當前獎勵額度
     */
    function getCurrentRewardAmount() public view returns (uint256) {
        return _currentRewardAmount;
    }

    /**
     * @dev Check if reward is enabled
     * @dev 檢查獎勵是否啟用
     */
    function isRewardEnabled() public view returns (bool) {
        return _rewardEnabled;
    }

    /**
     * @dev Calculate how many transfers are needed until next halving
     * @dev 計算距離下次減半還需多少次轉賬
     */
    function getTransfersUntilNextHalving() public view returns (uint256) {
        // If reward is already 0, return 0 / 如果獎勵已經為0，返回0
        if (_currentRewardAmount == 0 || !_rewardEnabled) {
            return 0;
        }

        uint256 nextHalvingPoint = ((_transferCount / HALVING_INTERVAL) + 1) * HALVING_INTERVAL;
        return nextHalvingPoint.sub(_transferCount);
    }

    /**
     * @dev Enable/disable reward system (owner only)
     * @dev 啟用/禁用獎勵系統 (僅所有者)
     * Note: If reward has been halved to 0, it cannot be re-enabled unless reward amount is reset
     * 注意：如果獎勵已經減半到0，將無法重新啟用，除非重置獎勵額度
     */
    function toggleReward(bool enabled) public onlyOwner {
        // If trying to enable reward but current reward amount is 0, reject the operation
        // 如果要啟用獎勵但當前獎勵額度為0，則拒絕操作
        if (enabled && _currentRewardAmount == 0) {
            revert("TRC20: cannot enable reward when amount is zero, please reset reward amount first");
        }

        _rewardEnabled = enabled;
        emit RewardToggled(enabled);
    }

    /**
     * @dev Fund reward pool for reward distribution (owner only)
     * @dev 為合約充值代幣用於獎勵發放 (僅所有者)
     */
    function fundRewardPool(uint256 amount) public onlyOwner {
        require(amount > 0, "TRC20: amount must be greater than zero");
        require(_balances[_owner] >= amount, "TRC20: insufficient owner balance");

        _balances[_owner] = _balances[_owner].sub(amount);
        _balances[address(this)] = _balances[address(this)].add(amount);
        emit Transfer(_owner, address(this), amount);
    }

    // Function to receive TRX
    // 接收TRX的函數
    receive() external payable {}
}
