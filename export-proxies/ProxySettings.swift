//
//  ProxySettings.swift
//  export-proxies
//
//  Created by Jan Vogt on 16.03.15.
//  Copyright (c) 2015 janvogt. All rights reserved.
//

import SystemConfiguration
import CoreFoundation
import Foundation

class ProxySettings {
    private var proxies = [Proxy]()
    private enum ProtocolIdentifier: String {
        case HTTP = "http", HTTPS = "https", FTP = "ftp", SOCKS = "socks"
        var envVars: [String] {
            get {
                func suffixProxy(label: String) -> String {
                    return "\(label)_proxy"
                }
                func lowerAndUpper(str: String) -> [String] {
                    return [str.lowercaseString, str.uppercaseString]
                }
                switch self {
                case .HTTP, .HTTPS, .FTP:
                    return lowerAndUpper(suffixProxy(self.rawValue))
                case .SOCKS:
                    return lowerAndUpper(suffixProxy("all"))
                }
            }
        }
    }
    private struct Protocol {
        let ident: ProtocolIdentifier
        let kHost, kPort, kEnabled: String
        init(ident: ProtocolIdentifier, kHost: String, kPort: String, kEnabled: String) {
            (self.ident, self.kHost, self.kPort, self.kEnabled) = (ident, kHost, kPort, kEnabled)
        }
    }
    private struct Proxy {
        let proto: ProtocolIdentifier
        let host: String
        let port: Int
        init(proto: ProtocolIdentifier, host: String, port: Int) {
            (self.proto, self.host, self.port) = (proto, host, port)
        }
        var url: String {
            get {
                return "\(proto.rawValue)://\(host):\(port)"
            }
        }
        var envSetings: [String] {
            get {
                return map(proto.envVars) {"\($0)=\(self.url)"}
            }
        }
    }
    private let protocols = [
        Protocol(ident: .HTTP,
            kHost: kSCPropNetProxiesHTTPProxy,
            kPort: kSCPropNetProxiesHTTPPort,
            kEnabled: kSCPropNetProxiesHTTPEnable),
        Protocol(ident: .HTTPS,
            kHost: kSCPropNetProxiesHTTPSProxy,
            kPort: kSCPropNetProxiesHTTPSPort,
            kEnabled: kSCPropNetProxiesHTTPSEnable),
        Protocol(ident: .FTP,
            kHost: kSCPropNetProxiesFTPProxy,
            kPort: kSCPropNetProxiesFTPPort,
            kEnabled: kSCPropNetProxiesFTPEnable),
        Protocol(ident: .SOCKS,
            kHost: kSCPropNetProxiesSOCKSProxy,
            kPort: kSCPropNetProxiesSOCKSPort,
            kEnabled: kSCPropNetProxiesSOCKSEnable)
    ]
    init?() {
        if let store = SCDynamicStoreCreateWithOptions(nil, "app", nil, nil, nil)?.takeRetainedValue() {
            if let proxy: NSDictionary = SCDynamicStoreCopyProxies(store)?.takeRetainedValue() {
                for proto in protocols {
                    if proxy[proto.kEnabled] == nil || proxy[proto.kEnabled]! as NSNumber == 0 || proxy[proto.kHost] == nil || proxy[proto.kHost] == nil {
                        continue
                    }
                    if let host = proxy[proto.kHost]? as? NSString {
                        if let port = proxy[proto.kPort]? as? NSNumber {
                            proxies.append(Proxy(proto: proto.ident, host:host, port: port.integerValue))
                        }
                    }
                }
            }
        } else {
            return nil
        }
    }
    var exports: String {
        get {
            var settings = [String]()
            for proxy in proxies {
                settings.extend(proxy.envSetings)
            }
            return "\n".join(map(settings) {"export \($0)"})
        }
    }
}
