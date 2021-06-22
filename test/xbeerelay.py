relay.callback(lambda dic : relay.send(relay.BLUETOOTH, 'xbee received {}'.format(dic['message'])))
relay.callback(lambda dic : print('xbee received message {}'.format(dic['message'])))