#junos-config
groups {
    transit-vpc {
        system {
            root-authentication {
                encrypted-password "$1$ZUlES4dp$OUwWo1g7cLoV/aMWpHUnC/"; ## SECRET-DATA
                ssh-rsa "${SshPublicKey}"; ## SECRET-DATA
                ssh-rsa "${LambdaSshPublicKey}";
            }
            services {
                ssh {
                    connection-limit 5;
                }
            }
        }
    }
}
apply-groups transit-vpc;
system {
    syslog {
        user * {
            any emergency;
        }
        file messages {
            any notice;
            authorization info;
        }
        file interactive-commands {
            interactive-commands any;
        }
    }
}
security {
    policies {
        from-zone trust to-zone trust {
            policy default-permit {
                match {
                    source-address any;
                    destination-address any;
                    application any;
                }
                then {
                    permit;
                }
            }
        }
        from-zone trust to-zone untrust {
            policy default-permit {
                match {
                    source-address any;
                    destination-address any;
                    application any;
                }
                then {
                    permit;
                }
            }
        }
        from-zone untrust to-zone trust {
            policy default-permit {
                match {
                    source-address any;
                    destination-address any;
                    application any;
                }
                then {
                    permit;
                }
            }
        }
    }
    zones {
        security-zone trust {
            tcp-rst;
            interfaces {
                ge-0/0/1.0;
                ge-0/0/2.0;
            }
        }
        security-zone untrust {
            host-inbound-traffic {
                system-services {
                    ike;
                }
                protocols {
                    bgp;
                }
            }
            interfaces {
                ge-0/0/0.0;
            }
        }
    }
}
interfaces {
    ge-0/0/0 {
        unit 0 {
            family inet {
                address ${PrimaryPrivateMgmtIpAddress}/24;
            }
        }
    }
    ge-0/0/1 {
        unit 0 {
            family inet {
                address ${PrimaryPrivateIngressIpAddress}/24;
            }
        }
    }
    ge-0/0/2 {
        unit 0 {
            family inet {
                address ${PrimaryPrivateEgressIpAddress}/24;
            }
        }
    }
}
policy-options {
    policy-statement EXPORT-DEFAULT {
        term default {
            from {
                route-filter 10.150.0.0/16 exact;
                route-filter 10.160.0.0/16 exact;
            }
            then accept;
        }
        term reject {
            then reject;
        }
    }
}
routing-instances {
    internet {
        instance-type virtual-router;
        interface ge-0/0/0.0;
        routing-options {
            static {
                route 0.0.0.0/0 next-hop 10.10.30.1;
                route 10.150.0.0/16 next-table intervpc.inet.0;
                route 10.160.0.0/16 next-table intervpc.inet.0;
            }
        }
    }
    intervpc {
        instance-type virtual-router;
        interface ge-0/0/1.0;
        interface ge-0/0/2.0;
        routing-options {
            static {
                route 10.150.0.0/16 next-hop 10.10.70.1;
                route 10.160.0.0/16 next-hop 10.10.70.1;
            }
        }
    }
}
routing-options {
    rib-groups {
        internet2intervpc {
            import-rib [ internet.inet.0 intervpc.inet.0 ];
        }
    }
}
