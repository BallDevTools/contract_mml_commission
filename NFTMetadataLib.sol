// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library NFTMetadataLib {
    function uint2str(uint256 _i) internal pure returns (string memory) {
        if (_i == 0) return "0";
        uint256 j = _i;
        uint256 len;
        while (j != 0) {
            unchecked { ++len; }
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (_i != 0) {
            unchecked { k = k - 1; }
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    function base64Encode(bytes memory data) internal pure returns (string memory) {
        string memory TABLE = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
        uint256 len = data.length;
        if (len == 0) return '';

        uint256 encodedLen = 4 * ((len + 2) / 3);
        bytes memory result = new bytes(encodedLen);
        uint256 i;
        uint256 j = 0;

        for (i = 0; i + 3 <= len;) {
            uint256 val = uint256(uint8(data[i])) << 16 |
                          uint256(uint8(data[i + 1])) << 8 |
                          uint256(uint8(data[i + 2]));
            result[j++] = bytes(TABLE)[(val >> 18) & 63];
            result[j++] = bytes(TABLE)[(val >> 12) & 63];
            result[j++] = bytes(TABLE)[(val >> 6) & 63];
            result[j++] = bytes(TABLE)[val & 63];
            unchecked { i += 3; }
        }

        if (i < len) {
            uint256 val = uint256(uint8(data[i])) << 16;
            if (i + 1 < len) val |= uint256(uint8(data[i + 1])) << 8;
            result[j++] = bytes(TABLE)[(val >> 18) & 63];
            result[j++] = bytes(TABLE)[(val >> 12) & 63];
            if (i + 1 < len) {
                result[j++] = bytes(TABLE)[(val >> 6) & 63];
                result[j++] = bytes(TABLE)[val & 63];
            } else {
                result[j++] = bytes(TABLE)[(val >> 6) & 63];
                result[j++] = '=';
            }
        }
        return string(result);
    }
}