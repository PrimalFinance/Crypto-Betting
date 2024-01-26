// SPDX-License-Identifier: MIT
pragma solidity >=0.8.19;

/// @title The interface for the Betting Pool Factory
/// @notice The Betting Pool Factory facilitates creation of 'betting pools'.
interface IBettingPoolFactory {
    /// @notice Emitted when the owner of the factory is changed
    /// @param oldOwner The owner before the owner was changed
    /// @param newOwner The owner after the owner was changed
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    /// @notice Emitted when a pool is created
    /// @param admin Admin of the contract.
    /// @param operator Operator of the pool.
    /// @param _token0 The first token of the pool by address sort order.
    /// @param _token1 The second token of the pool by address sort order.
    /// @param _intervalSeconds The intervals that the pool runs.
    /// return pool The address of the created pool.
    event PoolCreated(
        address admin,
        address operator,
        address indexed _token0,
        address indexed _token1,
        uint256 indexed _intervalSeconds,
        address pool
    );

    /// @notice Returns the current owner of the factory
    /// @dev Can be changed by the current owner via setOwner
    /// @return The address of the factory owner
    function owner() external view returns (address);

    /// @notice Returns the pool address for a given pair of tokens and a intervalSecond, or address 0 if it does not exist
    /// @dev _token0 and _token1 may be passed in either _token0/_token1 or _token1/_token0 order.
    /// @param _token0 The contract address of either _token0 or _token1.
    /// @param _token1 The contract address of the other token.
    /// @param _intervalSeconds The interval s that the pool runs.
    /// @return pool The pool address
    function getPool(
        address _token0,
        address _token1,
        uint256 _intervalSeconds
    ) external view returns (address pool);

    /// @notice Creates a pool for the given two tokens and fee
    /// @param _token0 One of the two tokens in the desired pool
    /// @param _token1 The other of the two tokens in the desired pool
    /// @param _intervalSeconds The interval that the pool runs.
    /// @dev _token0 and _token1 may be passed in either order: _token0/_token1 or _token1/_token0.
    /// The call will revert if the pool already exists, the _intervalSeconds is invalid, or the token arguments
    /// are invalid.
    /// @return pool The address of the newly created pool
    function createPool(
        address _token0,
        address _token1,
        address _feed0,
        address _feed1,
        uint256 _intervalSeconds
    ) external returns (address pool);

    /// @notice Updates the owner of the factory
    /// @dev Must be called by the current owner
    /// @param _owner The new owner of the factory
    function setOwner(address _owner) external;
}
