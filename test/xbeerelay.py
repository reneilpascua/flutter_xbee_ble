def padRelayData(data):
    '''
    Pads the data with null characters so the relayed message is a multiple of 16B.

    The message has an overhead of 6B, so the output must be of length 10, 26, 42, ...
    @param data - plaintext string to be relayed
    '''
    while(len(data) % 16 != 0):
        data += '\0'
    return data

def relayData(data):
    '''
    Relays the given plaintext data via BLE, with proper padding.
    '''
    relay.send(relay.BLUETOOTH, padRelayData(data))