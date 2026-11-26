// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @notice Minimal view of the SPACE ID Agent ID registry (ERC-721 style balanceOf).
interface IAgentID {
    function balanceOf(address owner) external view returns (uint256);
}

/// @title VouchNet - an on-chain web of trust for Agent ID holders on BNB Smart Chain
/// @notice Agent ID holders vouch for other Agent ID holders with a tag and a short note.
///         Each active vouch received = 10 points, each mutual (two-way) vouch = +5 bonus.
///         No owner, no admin, holds no funds, no token approvals.
contract VouchNet {
    // ---------------------------------------------------------------- constants
    IAgentID public constant AGENT_ID = IAgentID(0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F);

    uint256 public constant POINTS_PER_VOUCH = 10;
    uint256 public constant MUTUAL_BONUS = 5;
    uint256 public constant DAILY_LIMIT = 10;     // new vouches per wallet per UTC day (07:00 Vietnam time)
    uint256 public constant MAX_NOTE_BYTES = 140;
    uint8 public constant TAG_COUNT = 6;          // 0 Reliable, 1 Builder, 2 Helpful, 3 Trader, 4 Creator, 5 Friendly

    // ---------------------------------------------------------------- storage
    struct Vouch {
        bool active;
        uint8 tag;
        uint64 time;
        string note;
    }

    struct Record {
        address from;
        address to;
        uint8 tag;
        uint64 time;
    }

    /// @dev vouchOf[from][to]
    mapping(address => mapping(address => Vouch)) private vouchOf;

    mapping(address => uint256) public receivedCount;
    mapping(address => uint256) public givenCount;
    mapping(address => uint256) public mutualCount;
    mapping(address => uint256[6]) private tagCounts;

    mapping(address => bool) public isMember;
    address[] private members;

    mapping(address => uint256) private dayOf;
    mapping(address => uint256) private usedToday;

    Record[] private history;

    // ---------------------------------------------------------------- events & errors
    event Vouched(address indexed from, address indexed to, uint8 tag, string note, bool mutual);
    event Revoked(address indexed from, address indexed to);
    event NewMember(address indexed member, uint256 count);

    error NotAgentID(address account);
    error SelfVouch();
    error AlreadyVouched();
    error NotVouched();
    error BadTag();
    error NoteTooLong();
    error DailyLimit();

    // ---------------------------------------------------------------- write
    /// @notice Vouch for another Agent ID holder.
    /// @param to   the Agent ID wallet you vouch for
    /// @param tag  0 Reliable, 1 Builder, 2 Helpful, 3 Trader, 4 Creator, 5 Friendly
    /// @param note short public note (max 140 bytes)
    function vouch(address to, uint8 tag, string calldata note) external {
        if (to == msg.sender) revert SelfVouch();
        if (tag >= TAG_COUNT) revert BadTag();
        if (bytes(note).length > MAX_NOTE_BYTES) revert NoteTooLong();
        if (AGENT_ID.balanceOf(msg.sender) == 0) revert NotAgentID(msg.sender);
        if (AGENT_ID.balanceOf(to) == 0) revert NotAgentID(to);

        Vouch storage v = vouchOf[msg.sender][to];
        if (v.active) revert AlreadyVouched();

        uint256 today = block.timestamp / 1 days;
        if (dayOf[msg.sender] != today) {
            dayOf[msg.sender] = today;
            usedToday[msg.sender] = 0;
        }
        if (usedToday[msg.sender] >= DAILY_LIMIT) revert DailyLimit();
        unchecked { usedToday[msg.sender] += 1; }

        v.active = true;
        v.tag = tag;
        v.time = uint64(block.timestamp);
        v.note = note;

        unchecked {
            receivedCount[to] += 1;
            givenCount[msg.sender] += 1;
            tagCounts[to][tag] += 1;
        }

        bool isMutual = vouchOf[to][msg.sender].active;
        if (isMutual) {
            unchecked {
                mutualCount[to] += 1;
                mutualCount[msg.sender] += 1;
            }
        }

        _join(msg.sender);
        _join(to);

        history.push(Record(msg.sender, to, tag, uint64(block.timestamp)));
        emit Vouched(msg.sender, to, tag, note, isMutual);
    }

    /// @notice Take back a vouch you gave.
    function revoke(address to) external {
        Vouch storage v = vouchOf[msg.sender][to];
        if (!v.active) revert NotVouched();

        v.active = false;
        receivedCount[to] -= 1;
        givenCount[msg.sender] -= 1;
        tagCounts[to][v.tag] -= 1;

        if (vouchOf[to][msg.sender].active) {
            mutualCount[to] -= 1;
            mutualCount[msg.sender] -= 1;
        }
        emit Revoked(msg.sender, to);
    }

    function _join(address a) private {
        if (!isMember[a]) {
            isMember[a] = true;
            members.push(a);
            emit NewMember(a, members.length);
        }
    }

    // ---------------------------------------------------------------- read
    /// @notice Reputation score: 10 per active vouch received + 5 per mutual vouch.
    function scoreOf(address a) public view returns (uint256) {
        return receivedCount[a] * POINTS_PER_VOUCH + mutualCount[a] * MUTUAL_BONUS;
    }

    /// @notice One-call trust check for dApps and AI agents:
    ///         holds an Agent ID AND has at least `minVouches` active vouches from other agents.
    function isTrusted(address a, uint256 minVouches) external view returns (bool) {
        return AGENT_ID.balanceOf(a) > 0 && receivedCount[a] >= minVouches;
    }

    function hasAgentID(address a) public view returns (bool) {
        return AGENT_ID.balanceOf(a) > 0;
    }

    function profile(address a)
        external
        view
        returns (
            bool agent,
            uint256 received,
            uint256 given,
            uint256 mutualVouches,
            uint256 score,
            uint256[6] memory tags
        )
    {
        return (hasAgentID(a), receivedCount[a], givenCount[a], mutualCount[a], scoreOf(a), tagCounts[a]);
    }

    function getVouch(address from, address to)
        external
        view
        returns (bool active, uint8 tag, uint64 time, string memory note)
    {
        Vouch storage v = vouchOf[from][to];
        return (v.active, v.tag, v.time, v.note);
    }

    function vouchesLeftToday(address a) external view returns (uint256) {
        if (dayOf[a] != block.timestamp / 1 days) return DAILY_LIMIT;
        return DAILY_LIMIT - usedToday[a];
    }

    function memberCount() external view returns (uint256) {
        return members.length;
    }

    function vouchCount() external view returns (uint256) {
        return history.length;
    }

    function getMembers(uint256 offset, uint256 limit) external view returns (address[] memory out) {
        uint256 n = members.length;
        if (offset >= n) return new address[](0);
        uint256 end = offset + limit > n ? n : offset + limit;
        out = new address[](end - offset);
        for (uint256 i = offset; i < end; i++) out[i - offset] = members[i];
    }

    /// @notice Latest vouches, newest first.
    function recentVouches(uint256 limit) external view returns (Record[] memory out) {
        uint256 n = history.length;
        uint256 k = limit > n ? n : limit;
        out = new Record[](k);
        for (uint256 i = 0; i < k; i++) out[i] = history[n - 1 - i];
    }
}
