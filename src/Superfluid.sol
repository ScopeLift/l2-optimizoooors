// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.16;

import {IERC20} from "src/interfaces/IERC20.sol";
import {IWETH} from "src/interfaces/IWETH.sol";
import {Create2} from "src/lib/Create2.sol";
import {SafeTransferLib} from "src/lib/SafeTransferLib.sol";

// ============================
// ======== Interfaces ========
// ============================

interface ISuperfluidToken is IERC20 {
  function getHost() external view returns (address host);
  function getUnderlyingToken() external view returns (address token);
  function upgradeTo(address to, uint amount, bytes calldata data) external;
}

interface ISuperfluid {
  function callAgreement(
    address agreementClass,
    bytes calldata callData,
    bytes calldata userData
  ) external returns (bytes memory returnedData);
}

interface ISuperfluidCFA {
  function authorizeFlowOperatorWithFullControl(
    ISuperfluidToken token,
    address flowOperator,
    bytes calldata ctx
  ) external returns (bytes memory newCtx);

  function createFlowByOperator(
    ISuperfluidToken token,
    address sender,
    address receiver,
    int96 flowRate,
    bytes calldata ctx
  ) external returns (bytes memory newCtx);

  function updateFlowByOperator(
    ISuperfluidToken token,
    address sender,
    address receiver,
    int96 flowRate,
    bytes calldata ctx
  ) external returns (bytes memory newCtx);

  function deleteFlowByOperator(
    ISuperfluidToken token,
    address sender,
    address receiver,
    bytes calldata ctx
  ) external returns (bytes memory newCtx);
}

// =========================
// ======== Helpers ========
// =========================

// Amounts supplied or withdrawn are specified as a fraction of the user's
// balance. You can pass up to 31 bytes of data to define this fraction. If zero
// bytes are provided, the max amount is used. If one byte is provided, that
// data is considered the numerator, and the denominator becomes 255, which is
// the max value of a single byte. If two bytes are provided, the data is still
// considered the numerator, but the denominator becomes 65_535, which is the
// max value of 2 bytes. This pattern continues through 31 bytes, and this
// method will revert if you try passing 32 bytes or more of calldata.
// Realistically you'll never need that much anyway.
function parseAmount(uint balance, bytes calldata data) pure returns (uint) {
  if (data.length == 0) return balance;

  uint bits = data.length * 8;
  uint fraction = uint(bytes32(data) >> (256 - bits));
  uint maxUintN = (1 << bits) - 1;
  return balance * fraction / maxUintN;
}

// =========================
// ====== SuperToken =======
// =========================

contract SuperTokenWrapper {
  using SafeTransferLib for IERC20;

  IERC20 public immutable TOKEN;
  ISuperfluidToken public immutable ASSET;

  constructor(address asset) {
    ASSET = ISuperfluidToken(asset);
    TOKEN = IERC20(ASSET.getUnderlyingToken());
    TOKEN.safeApprove(address(ASSET), type(uint).max);
  }

  fallback() external {
    uint balance = TOKEN.balanceOf(msg.sender);
    uint amt = parseAmount(balance, msg.data);
    TOKEN.safeTransferFrom(msg.sender, address(this), amt);
    ASSET.upgradeTo(msg.sender, amt * 1e12, hex"");
  }
}

// =========================
// ======= Operator ========
// =========================

/// @notice This contract should be granted permission to manage flows on behalf
/// of a user via `authorizeFlowOperatorWithFullControl`
contract SuperFlowOperator {
  ISuperfluidCFA public immutable CFA;
  ISuperfluidToken public immutable ASSET;
  SuperFlowCreate public immutable CREATE;
  SuperFlowUpdate public immutable UPDATE;
  SuperFlowDelete public immutable DELETE;

  constructor(ISuperfluidCFA cfa, ISuperfluidToken asset) {
    CFA = cfa;
    ASSET = asset;
    CREATE = new SuperFlowCreate();
    UPDATE = new SuperFlowUpdate();
    DELETE = new SuperFlowDelete();
  }

  function createFlow(address sender, address receiver, int96 flowRate)
    external
  {
    require(msg.sender == address(CREATE), "Call through child.");
    ISuperfluid(ASSET.getHost()).callAgreement(
      address(CFA),
      abi.encodeCall(
        CFA.createFlowByOperator, (ASSET, sender, receiver, flowRate, hex"")
      ),
      hex""
    );
  }

  function updateFlow(address sender, address receiver, int96 flowRate)
    external
  {
    require(msg.sender == address(UPDATE), "Call through child.");
    ISuperfluid(ASSET.getHost()).callAgreement(
      address(CFA),
      abi.encodeCall(
        CFA.updateFlowByOperator, (ASSET, sender, receiver, flowRate, hex"")
      ),
      hex""
    );
  }

  function deleteFlow(address sender, address receiver) external {
    require(msg.sender == address(DELETE), "Call through child.");
    ISuperfluid(ASSET.getHost()).callAgreement(
      address(CFA),
      abi.encodeCall(CFA.deleteFlowByOperator, (ASSET, sender, receiver, hex"")),
      hex""
    );
  }
}

contract SuperFlowCreate {
  SuperFlowOperator public immutable OPERATOR;

  constructor() {
    OPERATOR = SuperFlowOperator(msg.sender);
  }

  fallback() external {
    address receiver = address(bytes20(msg.data[:20]));
    bytes calldata flowRateData = msg.data[20:];
    uint len = flowRateData.length;
    require(len <= 32, "amount too long.");
    uint userFlowRate = uint(bytes32(flowRateData) >> (256 - len * 8));
    require(userFlowRate < uint(uint96(type(int96).max)), "amount too high.");
    int96 flowRate = int96(int(userFlowRate));
    OPERATOR.createFlow(msg.sender, receiver, flowRate);
  }
}

contract SuperFlowUpdate {
  SuperFlowOperator public immutable OPERATOR;

  constructor() {
    OPERATOR = SuperFlowOperator(msg.sender);
  }

  fallback() external {
    address receiver = address(bytes20(msg.data[:20]));
    bytes calldata flowRateData = msg.data[20:];
    uint len = flowRateData.length;
    require(len <= 32, "amount too long.");
    uint userFlowRate = uint(bytes32(flowRateData) >> (256 - len * 8));
    require(userFlowRate < uint(uint96(type(int96).max)), "amount too high.");
    int96 flowRate = int96(int(userFlowRate));
    OPERATOR.updateFlow(msg.sender, receiver, flowRate);
  }
}

contract SuperFlowDelete {
  SuperFlowOperator public immutable OPERATOR;

  constructor() {
    OPERATOR = SuperFlowOperator(msg.sender);
  }

  fallback() external {
    address receiver = address(bytes20(msg.data[:20]));
    OPERATOR.deleteFlow(msg.sender, receiver);
  }
}

// =========================
// ======= Factories =======
// =========================

contract SuperOperatorFactory {
  address public immutable CFA;

  event OperatorDeployed(address operator, address indexed asset);

  constructor(address cfa) {
    CFA = cfa;
  }

  function deploy(address asset) external returns (address) {
    address operator = address(
      new SuperFlowOperator{salt: _salt(asset)}(ISuperfluidCFA(CFA), ISuperfluidToken(asset))
    );

    emit OperatorDeployed(operator, asset);
    return operator;
  }

  function getOperator(address asset) public view returns (address) {
    address operator = computeAddress(asset);
    if (operator.code.length == 0) return (address(0));
    return operator;
  }

  function isDeployed(address asset) external view returns (bool) {
    address operator = getOperator(asset);
    return operator != address(0);
  }

  function computeAddress(address asset) public view returns (address) {
    return Create2.computeCreate2Address(
      _salt(asset),
      address(this),
      type(SuperFlowOperator).creationCode,
      abi.encode(CFA, asset)
    );
  }

  function _salt(address asset) internal pure returns (bytes32) {
    return bytes32(uint(uint160(asset)));
  }
}
