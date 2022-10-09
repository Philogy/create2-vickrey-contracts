pragma solidity ^0.8.0;

library ECVerify {

    function ecverify(bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        internal
        pure
        returns (address signature_address)
    {
        // Version of signature should be 27 or 28, but 0 and 1 are also possible
        if (v < 27) {
            v += 27;
        }

        // EIP 155: 2 * chainId + 35
        if (v > 28) {
            v = v % 2 == 1 ? 27 : 28;
        }

        require(v == 27 || v == 28);

        signature_address = ecrecover(hash, v, r, s);

        // ecrecover returns zero on error
        require(signature_address != address(0x0), "ECVerify revert");

        return signature_address;
    }
}
