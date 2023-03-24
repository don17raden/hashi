// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity ^0.8.17;

import "./interfaces/IMessageRelay.sol";
import "./interfaces/IMessageDispatcher.sol";

contract Yaho is MessageDispatcher {
    mapping(uint256 => bytes32) public hashes;
    uint256 private count;

    error NoMessagesGiven(address emitter);
    error NoMessageIdsGiven(address emitter);
    error NoAdaptersGiven(address emitter);
    error UnequalArrayLengths(address emitter);

    function dispatchMessages(Message[] memory messages) public payable returns (bytes32[] memory) {
        if (messages.length == 0) revert NoMessagesGiven(address(this));
        bytes32[] memory messageIds = new bytes32[](messages.length);
        for (uint i = 0; i < messages.length; i++) {
            uint256 id = count;
            hashes[id] = calculateHash(block.chainid, id, address(this), msg.sender, messages[i]);
            messageIds[i] = bytes32(id);
            emit MessageDispatched(bytes32(id), msg.sender, messages[i].toChainId, messages[i].to, messages[i].data);
            count++;
        }
        return messageIds;
    }

    function relayMessagesToAdapters(
        uint256[] memory messageIds,
        address[] memory adapters,
        address[] memory destinationAdapters
    ) external payable returns (bytes32[] memory) {
        if (messageIds.length == 0) revert NoMessageIdsGiven(address(this));
        if (adapters.length == 0) revert NoAdaptersGiven(address(this));
        if (adapters.length != destinationAdapters.length) revert UnequalArrayLengths(address(this));
        uint256[] memory uintIds = new uint256[](messageIds.length);
        for (uint i = 0; i < messageIds.length; i++) {
            uintIds[i] = uint256(messageIds[i]);
        }
        bytes32[] memory adapterReciepts = new bytes32[](adapters.length);
        for (uint i = 0; i < adapters.length; i++) {
            adapterReciepts[i] = IMessageRelay(adapters[i]).relayMessages(uintIds, destinationAdapters[i]);
        }
        return adapterReciepts;
    }

    function dispatchMessagesToAdapters(
        Message[] memory messages,
        address[] memory adapters,
        address[] memory destinationAdapters
    ) external payable returns (bytes32[] memory messageIds, bytes32[] memory) {
        if (adapters.length == 0) revert NoAdaptersGiven(address(this));
        messageIds = dispatchMessages(messages);
        uint256[] memory uintIds = new uint256[](messageIds.length);
        for (uint i = 0; i < messageIds.length; i++) {
            uintIds[i] = uint256(messageIds[i]);
        }
        bytes32[] memory adapterReciepts = new bytes32[](adapters.length);
        for (uint i = 0; i < adapters.length; i++) {
            adapterReciepts[i] = IMessageRelay(adapters[i]).relayMessages(uintIds, destinationAdapters[i]);
        }
        return (messageIds, adapterReciepts);
    }

    function calculateHash(
        uint256 chainId,
        uint256 id,
        address origin,
        address sender,
        Message memory message
    ) public pure returns (bytes32 calculatedHash) {
        calculatedHash = keccak256(abi.encode(chainId, id, origin, sender, message));
    }
}
