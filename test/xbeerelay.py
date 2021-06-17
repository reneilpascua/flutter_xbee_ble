def padRelayData(data):
    while((len(data)+6) % 16 != 0):
        data += '\0'
    return data

def relayData(data):
    relay.send(relay.BLUETOOTH, padRelayData(data))

def receiveCallback(dic):
    print('received message from ',dic['sender'])
    print(dic['message'])
    # relayData('xbee received {}'.format(dic['message']))

relay.callback(receiveCallback)


