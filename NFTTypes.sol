// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library NFTTypes {
    struct NFTImage {
        string imageURI;
        string name;
        string description;
        uint256 planId;
        uint256 createdAt;
    }
}
