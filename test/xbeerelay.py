# lack of indentation required for micropython
def padRelayData(data):
while((len(data)+6) % 16 != 0): data += '\0'
return data








relayData = lambda data : relay.send(relay.BLUETOOTH, padRelayData(data))

relay.callback(lambda dic : relayData('xbee received {}'.format(dic['message'])))