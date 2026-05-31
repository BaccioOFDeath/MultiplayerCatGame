// MCManager.swift
import MultipeerConnectivity

protocol MCManagerDelegate: AnyObject {
    func connectedPeersChanged(_ peers: [MCPeerID])
    func receivedData(_ data: Data, from peerID: MCPeerID)
}

class MCManager: NSObject {
    static let shared = MCManager()
    let peerID: MCPeerID
    let session: MCSession

    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    weak var delegate: MCManagerDelegate?
    private let serviceType = "cat-splay"

    private override init() {
        let deviceName = UIDevice.current.name
        let uniqueName = deviceName + "-" + UUID().uuidString
        peerID = MCPeerID(displayName: uniqueName)
        session = MCSession(peer: peerID,
                            securityIdentity: nil,
                            encryptionPreference: .required)
        super.init()
        session.delegate = self
    }

    func startHostingAndBrowsing() {
        advertiser = MCNearbyServiceAdvertiser(peer: peerID,
                                               discoveryInfo: nil,
                                               serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
        browser = MCNearbyServiceBrowser(peer: peerID,
                                         serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }

    private func send(_ data: Data) {
        guard !session.connectedPeers.isEmpty else { return }
        try? session.send(data, toPeers: session.connectedPeers, with: .reliable)
    }

    private func sendMessage(_ msg: [String: Any]) {
        guard let d = try? JSONSerialization.data(withJSONObject: msg) else { return }
        send(d)
    }

    func sendPosition(xPct: Double, yPct: Double) {
        sendMessage([
            "type": "position",
            "peer": peerID.displayName,
            "xPct": xPct,
            "yPct": yPct
        ])
    }

    func sendHit() {
        sendMessage(["type": "hit"])
    }

    func broadcastTraffic(_ positions: [[String: Double]]) {
        sendMessage([
            "type": "traffic",
            "positions": positions
        ])
    }
}

extension MCManager: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        delegate?.connectedPeersChanged(session.connectedPeers)
    }
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        delegate?.receivedData(data, from: peerID)
    }
    func session(_: MCSession, didReceive _: InputStream, withName _: String, fromPeer _: MCPeerID) {}
    func session(_: MCSession, didStartReceivingResourceWithName _: String,
                 fromPeer _: MCPeerID, with _: Progress) {}
    func session(_: MCSession, didFinishReceivingResourceWithName _: String,
                 fromPeer _: MCPeerID, at _: URL?, withError _: Error?) {}
}

extension MCManager: MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ adv: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext _: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        invitationHandler(true, session)
    }
}

extension MCManager: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser,
                 foundPeer peerID: MCPeerID,
                 withDiscoveryInfo _: [String: String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
    }
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer _: MCPeerID) {
        delegate?.connectedPeersChanged(session.connectedPeers)
    }
    func browser(_ browser: MCNearbyServiceBrowser,
                 didNotStartBrowsingForPeers error: Error) {
        print("Browser failed: \(error)")
    }
}
