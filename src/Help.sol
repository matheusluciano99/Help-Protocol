// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {Counter} from "@openzeppelin/contracts/utils/Counters.sol";

contract Help {
    // Enum for the donations' status
    enum Status {
        PENDING,
        SENT,
        RECEIVED,
        CANCELLED
    }

    // maybe change this
    enum DonationType {
        MONEY,
        UTILS,
        MONEY_AND_UTILS
    }

    // Donations' status
    Status private status;

    // Mapping donors to the value donated
    mapping(address => uint256) public donors;

    // Mapping beneficiaries to the values received
    mapping(address => uint256) public beneficiaries;

    address[] public donorsList;
    address[] public beneficiariesList;

    // List of basic donations needed
    string[] public basics;

    // Struct to store the items donated
    struct Item {
        string item;
        uint256 value;
        string condition;
        address donor;
        DonationType donationType;
    }

    // List of donated items
    Item[] public items;

    // Logging important events
    event Donation(
        address indexed donor,
        address indexed beneficiary,
        Item item
    );

    event DonationReceived(address indexed beneficiary, Item item);

    event DonationCancelled(
        address indexed donor,
        address indexed beneficiary,
        Item item
    );

    function getStatus() external view returns (Status) {
        return status;
    }

    function addToListOfNecessities(string calldata itemName) external {
        // onlyOwner
        require(bytes(itemName).length > 0, "Item's name can't be blank!");
        require(
            !isInListOfNecessities(itemName),
            "Item is already in the list of necessities"
        );

        basics.push(itemName);

        emit ItemAddedToListOfNecessities(itemName);
    }

    function removeFromListOfNecessities(string calldata itemName) external {
        // onlyOwner
        require(bytes(itemName).length > 0, "Item's name can't be blank!");
        require(
            isInListOfNecessities(itemName),
            "Item is already in the list of necessities"
        );

        bool found = false;
        for (uint256 i = 0; i < basics.length; i++) {
            if (
                keccak256(abi.encodePacked(basics[i])) ==
                keccak256(abi.encodePacked(itemName))
            ) {
                basics[i] = basics[basics.length - 1];
                basics.pop();
                found = true;
                break;
            }
        }

        if (found) {
            emit ItemRemovedFromListOfNecessities(itemName);
            return true;
        } else {
            return false;
        }
    }

    function DonateTo(
        address beneficiary,
        DonationType donationType,
        Item calldata item
    ) external payable {
        require(isDonor[msg.sender], "The sender is not registred!"); // a logging function is needed
        require(beneficiary != address(0), "Beneficiary's address is invalid!");

        if (donationType == DonationType.MONEY) {
            require(item.value > 0, "Value must be more than 0!");
        } else if (donationType == DonationType.UTILS) {
            require(
                isInListOfNecessities(item.item),
                "Item's not in the list of necessities!"
            );
        } else {
            require(
                item.value > 0 || isInListOfNecessities(item.item),
                "Invalid donation!"
            );
        }

        // update the mappings of the donors and beneficiaries
        donors[msg.sender] += item.value;
        beneficiaries[beneficiary].totalReceived += item.value;

        // stores the item donated
        if (donationType == DonationType.MONEY) {
            items[_itemIds.current()] = Item(
                item.item,
                item.value,
                item.condition,
                msg.sender,
                donationType
            );
        } else if (donationType == DonationType.UTILS) {
            items[_itemIds.current()] = Item(
                "Util",
                0,
                item.condition,
                msg.sender,
                donationType
            );
        } else {
            items[_itemIds.current()] = Item(
                item.item,
                item.value,
                item.condition,
                msg.sender,
                donationType
            );
        }

        // increment item counter
        _itemIds.increment();

        status = Status.SENT;

        emit Donation(msg.sender, beneficiary, item);
    }

    function inBasicItemsList(
        string calldata item
    ) internal view returns (bool) {
        for (uint256 i = 0; i < basics.length; i++) {
            if (
                keccak256(abi.encodePacked(basics[i])) ==
                keccak256(abi.encodePacked(item))
            ) {
                return true;
            }
        }
        return false;
    }

    function isDonorInList(address donor) internal view returns (bool) {
        for (uint256 i = 0; i < donorsList.length; i++) {
            if (donorsList[i] == donor) {
                return true;
            }
        }
        return false;
    }

    function isBeneficiaryInList(
        address beneficiary
    ) internal view returns (bool) {
        for (uint256 i = 0; i < beneficiariesList.length; i++) {
            if (beneficiariesList[i] == beneficiary) {
                return true;
            }
        }
        return false;
    }

    function ReceiveDonation() external {
        require(msg.sender != address(0), "Invalid address!");
        require(beneficiaries[msg.sender] > 0, "There's no donation pending!");
        require(status == Status.SENT, "Donation was not sent!");

        uint256 amountToReceive = beneficiaries[msg.sender];

        beneficiaries[msg.sender] -= amountToReceive;
        payable(msg.sender).transfer(amountToReceive);

        status = Status.RECEIVED;

        emit DonationReceived(msg.sender, amountToReceive);
    }

    // change this one
    function CancelDonation(address beneficiary) external {
        require(msg.sender != address(0), "Invalid address!");
        require(donors[msg.sender] > 0, "There's no donation pending!");
        require(status == Status.SENT, "Donation was not sent!"");
        require(
            beneficiaries[beneficiary] > 0,
            "Beneficiary has no pending donation!"
        );

        uint256 amountToCancel = donors[msg.sender];

        // update the mappings of the donors and beneficiaries
        donors[msg.sender] -= amountToCancel;
        beneficiaries[beneficiary] -= amountToCancel;

        payable(msg.sender).transfer(amountToCancel);

        status = Status.CANCELLED;

        emit DonationCancelled(msg.sender, beneficiary, amountToCancel);
    }
}
