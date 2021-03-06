# ctlvnet
本ツール群はLinux(Ubuntuを想定しています)で仮想ネットワークを構築するためのものです。

## 初期設定
仮想ノードを作成するためにdockerを設定します。所要時間は10-20分です。  
    $ ./mkimage node

仮想ノードはエンドポイントデバイスやルータとして使うことができます。

## 使い方
構築する仮想ネットワークによって使用するツールが異なります。  
以下はツールの使い方の説明に焦点を当てているため、その他コマンドの仕様などに関しては正確な説明に努めていますが、それを保証するものではありません。


### ペアインタフェースの作成
仮想ネットワークでは、常にインタフェースの対向にもう一つのインタフェースが存在します。  
ip linkコマンドで仮想インタフェースを作成すると、このコマンドを実行したホストの仮想ネットワーク(名前)空間に2つのペアの仮想インタフェースを作成します。  
この技術を用いて、実ホスト(Real Host: 略 RH)の仮想ネットワーク空間にペアの仮想インタフェースを追加します。  

    $ ./ctl2net.sh connect - - - -

次の図のようなネットワークが構成されます。

![peer](https://github.com/yuno-x/ctlvnet/raw/img/peer.png)

試しに以下のコマンドを実行してみてください。

    $ ip address

おそらく veth0, veth1 のペアのインタフェースが生成されていると思います。  
片方のインタフェースから dhclient コマンドでパケットを送って、もう片方のインタフェースで tcpdump コマンドを実行してパケットをキャプチャしてみるとパケットが送信できていることを確認することができます。  

    $ sudo dhclient veth0

を実行してから、別のターミナルで以下のコマンドを実行してみてください。

    $ sudo tcpdump -i veth1 -ln#
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on veth1, link-type EN10MB (Ethernet), capture size 262144 bytes
        1  21:43:37.166102 IP 0.0.0.0.68 > 255.255.255.255.67: BOOTP/DHCP, Request from 16:3e:3f:18:82:a9, length 300
        2  21:43:40.784108 IP 0.0.0.0.68 > 255.255.255.255.67: BOOTP/DHCP, Request from 16:3e:3f:18:82:a9, length 300
        3  21:43:43.128187 IP 0.0.0.0.68 > 255.255.255.255.67: BOOTP/DHCP, Request from 16:3e:3f:18:82:a9, length 300
    ^C
    3 packets captured
    3 packets received by filter
    0 packets dropped by kernel

きちんとDHCPのリクエストを送れていることがわかります。

ただし、上記ではIPアドレスが振られていません。  
次はIPアドレスを割り振ってみましょう。

    $ sudo ip address add 172.18.100.1/24 dev veth0
    $ sudo ip address add 172.18.100.2/24 dev veth1

IPアドレスが割り振られました。しかし、pingコマンドなどで疎通を確認してみても通信ができません。

    $ ping -I veth0 172.18.100.2
    ^C

ここで ARP テーブルを見てみましょう。

    $ ip neigh
    ~
    172.18.100.2 dev veth0  FAILED
    ~

と表示されるはずです。  
理由ははっきりとは分かりませんが、リプライが返って来ないとつまらないでしょう。  
次は仮想ノードを作成して疎通を確認してみましょう。  

その前にインタフェースを削除しましょう。

    $ sudo ip link del veth0

実ホストではipコマンドを用いて手動でインタフェースを削除する必要があります。  
仮想インタフェースは対になっていますので、対向のインタフェースであるveth1も削除されます。

### 仮想ノードの作成とリンクの作成
以下のコマンドで仮想ネットワークにノードを作成し、実ホストと接続してください。

    $ ./mkcontainer.sh node node1
    $ ./ctl2net.sh node1 172.18.100.101/24 - 172.18.100.100/24

ここでpingコマンドを実行してみると仮想ノードとパケットをやりとりすることができることがわかります。

    $ ping 172.18.100.101
    $ sudo docker exec -it node1 172.18.100.100

当然、ターミナルを2つ用意し、同時にpingパケットを送ることも可能です。  
以下では実ホストでネットワーク系のコマンドを打つときのプロンプトとして "(RH)$ ", node1のプロンプトとして "(node1)# "を使用しています。

    [Real Host]
    (RH)$ ping 172.18.100.101

    [node1]
    $ sudo docker exec -it node1 bash
    (node1)# ping 172.18.100.100

またノード同士を接続することもできます。

    $ ./mkcontainer.sh node node2
    $ ./ctl2ctl.sh connect node1 172.18.0.1/24 node2 172.18.0.2/24

    [node1]
    (node1)# ping 172.18.0.2

    [node2]
    (node2)# ping 172.18.0.1

![node](https://github.com/yuno-x/ctlvnet/raw/img/node.png)

どちらもデフォルトでapache2とcurlがインストールされているので、curlでapache2のデフォルトページをダウンロードすることも可能です。  
今回、node1とnode2の2つのホストをデータリンクさせましたが、3つ以上のホストをデータリンクさせることも可能です。  
これを実現するには仮想ブリッジを作成すればよい。Linuxの仮想ブリッジはラーニングスイッチとして作成され、MACアドレス-物理ポートの対応テーブル、いわゆるMACテーブルを参照してパケット(正確にはフレーム)をスイッチングします。  
次に仮想ブリッジを利用したネットワークを構築します。  
その前に node1, node2 を削除します。

    $ ./rmcontainer.sh node1 node2

実ホストRHとnode1はリンクされていましたが、node1削除と同時にnode1のインタフェースが削除されたので、実ホスト側の対向のインタフェースも同時に削除されます。


### L2ネットワーク構築
まずはnode1, node2, node3を作成します。

    $ ./mkcontainer node node1 node2 node3

仮想ブリッジbr0を作成後、node1, node2, node3の3つのノードを接続してみます。  

    $ ./ctl2net.sh setup br0 node1 172.18.0.1/24 node2 172.18.0.2/24 node3 172.18.0.3/24

上記のコマンドは以下のコマンドとほぼ同様の効果を示しています。  

    $ sudo ip link add br0 type bridge
    $ sudo ip link set br0 up
    $ ./ctl2net.sh connect br0 - node1 172.18.0.1/24
    $ ./ctl2net.sh connect br0 - node2 172.18.0.2/24
    $ ./ctl2net.sh connect br0 - node3 172.18.0.3/24

これによってnode1, node2, node3は相互にパケットを送受信できるようになりました。  
試しにnode1からnode2, node3へpingを送ってみます。  

    [node1]
    (node1)# ping 172.18.0.2
    ^C
    (node1)# ping 172.18.0.3
    ^C

疎通を確認することができるはずです。  

![switch](https://github.com/yuno-x/ctlvnet/raw/img/switch.png)

ちなみに仮想ブリッジは仮想インタフェースの一種として作成されます。  
つまり仮想ブリッジインタフェースを作成したホストは仮想ブリッジとなります。  
ブリッジの機能によってはIPパケットなどのL3フレームを送信することがあり
その場合ブリッジ自身にIPアドレスが割り振られていることになります。  
例えばブリッジを制御するためにブリッジへのSSHリモートアクセスを許可している場合、
ブリッジに割り振られたIPアドレスを指定してSSH接続します。  
そのためにブリッジはインタフェースとして作成されるといえるかもしれません。  
以下はスイッチbr0にIPアドレスを割り振って、node1からの疎通を確認しています。

    $ sudo ip address add 172.18.0.100/24 dev br0

    [node1]
    (node1)# ping 172.18.0.100
    ^C

疎通を確認できるはずです。
当然、仮想スイッチ(インタフェース)は同一ホストに複数作成することも可能です。

また、スイッチ同士を接続することも可能です。

    $ ./ctl2net.sh setup br1 node4 172.18.0.4/24 node5 172.18.0.5/24
    $ ./ctl2net.sh connect br0 - br1 -

    [node1]
    (node1)# ping 172.18.0.5
    ^C

これでブリッジbr0, br1を経由したnode1とnode5のパケット転送を行えたことを確認できました。  
ブリッジbr0のMACアドレステーブルは以下のコマンドで確認できます。

$ bridge fdb show br br0 | grep -vw "permanent"

もし、何も表示されなかったり、表示結果が少ないようならpingなどでパケットを送信してみてください。  
MACアドレステーブルにブリッジに埋め込まれているインタフェースとその対向のMACアドレスの関係が記録されていることが分かります。
このテーブルによってユニキャストへのパケットをセグメント内でブロードキャストせずに送ることができ、帯域を節約することができます。

さて、次はルーティングに触れますが、その前に作成したノードを削除しましょう。

    $ ./rmcontainer node1 node2 node3 node4 node5
    $ ./ctl2net delete br0 br1

以上で作成した環境は削除されたはずです。


### L3ネットワーク構築（スタティックルーティング）
次はL3ネットワークを構築するためにルータとネットワークセグメントが異なる2つのノードを作成します。  
そしてルータに2つのノードを接続し、IPアドレスを付与します。

    $ ./mkcontainer.sh node rt nodeA nodeB
    $ ./ctl2net.sh connect rt 172.18.0.254/24 nodeA 172.18.0.1/24
    $ ./ctl2net.sh connect rt 10.0.0.254/24 nodeB 10.0.0.1/24

![router](https://github.com/yuno-x/ctlvnet/raw/img/router.png)

さて、ではnodeAからnodeBへパケットを送ってみましょう。

    [nodeA]
    (nodeA)# ping 10.0.0.1
    ping: connect: Network is unreachable

上記のように送れないはずです。  
それはnodeAにnodeBへのルート情報を設定していないからです。  
試しにルーティングテーブルを確認してみましょう。  

    [nodeA]
    (nodeA)# ip route
    172.18.0.0/24 dev veth0 proto kernel scope link src 172.18.0.1

172.18.0.0/24 はルートの目的地となるネットワークセグメントです。  
dev veth0 はインタフェースveth0を使用してパケットを送出するという意味です。  
proto kernel はカーネルによってルート情報が作成されたことを示しています。  
scope link はデータリンク上に直接パケットを送出するという意味です。  
src 172.18.0.1 は 172.18.0.1 というIPアドレスを使用してパケットを送出するという意味です。  
しかし、10.0.0.0/24 へのルート情報はルーティングテーブルに登録されていません。  
ここでルーティングテーブルに 10.0.0.0/24 へのルート情報を登録してpingを送ってみましょう。

    [nodeA]
    (nodeA)# ip route add 10.0.0.0/24 via 172.18.0.1
    (nodeA)# ping 10.0.0.1
    ^C

返答がありません。これはたとえnodeBにpingパケットが届いたとしてもnodeBがnodeAへのルート情報を登録していないため返答をすることができないからです。  
nodeBへパケットが届いているか否かはnodeBでパケットキャプチャをすることで確認できます。

    [nodeB]
    (nodeB)# tcpdump -ln# icmp                      
    tcpdump: verbose output suppressed, use -v or -vv for full protocol decode
    listening on veth0, link-type EN10MB (Ethernet), capture size 262144 bytes
        1  22:06:23.930002 IP 172.18.0.1 > 10.0.0.1: ICMP echo request, id 7, seq 1, length 64
        2  22:06:24.946273 IP 172.18.0.1 > 10.0.0.1: ICMP echo request, id 7, seq 2, length 64
        3  22:06:25.970002 IP 172.18.0.1 > 10.0.0.1: ICMP echo request, id 7, seq 3, length 64
        4  22:06:26.994276 IP 172.18.0.1 > 10.0.0.1: ICMP echo request, id 7, seq 4, length 64
    ^C
    4 packets captured
    4 packets received by filter
    0 packets dropped by kernel

もし届いていなければルータ側で次の設定をしてみてください。

    [rt]
    rt# sysctl -w net.ipv4.ip_forward=1
    net.ipv4.ip_forward = 1

これでルータでIPパケットフォワーディング(IPパケット転送)ができるはずです。

さて、nodeBが返答を送信するためにはnodeBに172.18.0.0/24へのルート情報を登録します。
このようにすると、nodeAからnodeBへのpingが疎通します。

    [nodeB]
    (nodeB)# ip route add 172.18.0.0/24 via 10.0.0.254

    [nodeA]
    (nodeA)# ping 10.0.0.1
    PING 10.0.0.1 (10.0.0.1) 56(84) bytes of data.
    64 bytes from 10.0.0.1: icmp_seq=1 ttl=63 time=0.077 ms
    64 bytes from 10.0.0.1: icmp_seq=2 ttl=63 time=0.072 ms
    64 bytes from 10.0.0.1: icmp_seq=3 ttl=63 time=0.073 ms
    64 bytes from 10.0.0.1: icmp_seq=4 ttl=63 time=0.072 ms
    ^C
    --- 10.0.0.1 ping statistics ---
    4 packets transmitted, 4 received, 0% packet loss, time 3068ms
    rtt min/avg/max/mdev = 0.072/0.073/0.077/0.002 ms

当然、ノードを接続したスイッチをルータに接続しても、違うセグメント間でパケットを疎通できます。  
それを説明するために一旦作成したノードを削除しましょう。

    $ ./rmcontainer.sh rt nodeA nodeB

さて、ここで仮想ネットワークにセグメントA(172.18.1.0/24)とセグメントB(172.18.2.0/24)を作成しましょう。  
セグメントAにはnodeA1, nodeA2, nodeA3, rt0が属しており、セグメントBにはnodeB1, nodeB2, rt0が属しているとします。  
そのセグメントAの全ノードにセグメントBへのルートを、セグメントBの全ノードにセグメントBへのルートを設定します。

    $ ./mkcontainer.sh node rt0 nodeA1 nodeA2 nodeA3 nodeB1 nodeB2
    $ ./ctl2net.sh setup brA nodeA1 172.18.1.1/24 nodeA2 172.18.1.2/24 nodeA3 172.18.1.3/24 rt0 172.18.1.254/24
    $ ./ctl2net.sh setup brB nodeB1 172.18.2.1/24 nodeB2 172.18.2.2/24 rt0 172.18.2.254/24
    $ for NODE in nodeA1 nodeA2 nodeA3; do sudo docker exec -it $NODE ip route add 172.18.2.0/24 via 172.18.1.254; done
    $ for NODE in nodeB1 nodeB2; do sudo docker exec -it $NODE ip route add 172.18.1.0/24 via 172.18.2.254; done

![l3net](https://github.com/yuno-x/ctlvnet/raw/img/l3net.png)

これによって、例えばnodeA1からnodeB1, nodeB2へ、nodeB1からnodeA1, nodeA2, nodeA3へとpingを送ることができるようになりました。

そのように手動で設定したルート情報をスタティックルート(静的ルート)と呼びます。  
今回は簡単なネットワーク構成でしたからスタティックルートの設定もあまり大変ではありませんでしたが、
ネットワーク構成が複雑になればなるほどルート情報の設定が大変になります。

例えば次のようなネットワーク構成があるとします。

    $ ./mkcontainer.sh node rt1 rt2 rt3 rt4 nodeC1 nodeC2 nodeD1 nodeD2
    $ ./ctl2net.sh setup brC nodeC1 10.0.3.1/24 nodeC2 10.0.3.2/24 rt3 10.0.3.254/24
    $ ./ctl2net.sh setup brD nodeD1 192.168.4.1/24 nodeD2 192.168.4.2/24 rt4 192.168.4.254/24
    $ ./ctl2net.sh connect rt0 100.100.100.1/24 rt1 100.100.100.2/24
    $ ./ctl2net.sh connect rt1 110.110.110.1/24 rt2 110.110.110.2/24
    $ ./ctl2net.sh connect rt2 120.120.120.1/24 rt3 120.120.120.2/24
    $ ./ctl2net.sh connect rt2 130.130.130.1/24 rt4 130.130.130.2/24

さて、この構成で異なるセグメント間でノード同士の通信を行うにはどのようにルート情報を設定すればよいでしょうか。
様々な方法が考えられますが、ノードが属しているセグメント以外へのルート情報を設定するのか確実でしょう。
これはルータのようなパケット転送を行うノードも例外ではありません。

    $ for NODE in nodeA1 nodeA2 nodeA3; do sudo docker exec -it $NODE ip route add 100.100.100.0/24 via 172.18.1.254; done
    $ for NODE in nodeA1 nodeA2 nodeA3; do sudo docker exec -it $NODE ip route add 110.110.110.0/24 via 172.18.1.254; done
    $ for NODE in nodeA1 nodeA2 nodeA3; do sudo docker exec -it $NODE ip route add 120.120.120.0/24 via 172.18.1.254; done
    $ for NODE in nodeA1 nodeA2 nodeA3; do sudo docker exec -it $NODE ip route add 130.130.130.0/24 via 172.18.1.254; done
    $ for NODE in nodeA1 nodeA2 nodeA3; do sudo docker exec -it $NODE ip route add 10.0.3.0/24 via 172.18.1.254; done
    $ for NODE in nodeA1 nodeA2 nodeA3; do sudo docker exec -it $NODE ip route add 192.168.4.0/24 via 172.18.1.254; done

    $ for NODE in nodeB1 nodeB2; do sudo docker exec -it $NODE ip route add 100.100.100.0/24 via 172.18.2.254; done
    $ for NODE in nodeB1 nodeB2; do sudo docker exec -it $NODE ip route add 110.110.110.0/24 via 172.18.2.254; done
    $ for NODE in nodeB1 nodeB2; do sudo docker exec -it $NODE ip route add 120.120.120.0/24 via 172.18.2.254; done
    $ for NODE in nodeB1 nodeB2; do sudo docker exec -it $NODE ip route add 130.130.130.0/24 via 172.18.2.254; done
    $ for NODE in nodeB1 nodeB2; do sudo docker exec -it $NODE ip route add 10.0.3.0/24 via 172.18.2.254; done
    $ for NODE in nodeB1 nodeB2; do sudo docker exec -it $NODE ip route add 192.168.4.0/24 via 172.18.2.254; done

    $ for NODE in nodeC1 nodeC2; do sudo docker exec -it $NODE ip route add 100.100.100.0/24 via 10.0.3.254; done
    $ for NODE in nodeC1 nodeC2; do sudo docker exec -it $NODE ip route add 110.110.110.0/24 via 10.0.3.254; done
    $ for NODE in nodeC1 nodeC2; do sudo docker exec -it $NODE ip route add 120.120.120.0/24 via 10.0.3.254; done
    $ for NODE in nodeC1 nodeC2; do sudo docker exec -it $NODE ip route add 130.130.130.0/24 via 10.0.3.254; done
    $ for NODE in nodeC1 nodeC2; do sudo docker exec -it $NODE ip route add 172.18.1.0/24 via 10.0.3.254; done
    $ for NODE in nodeC1 nodeC2; do sudo docker exec -it $NODE ip route add 172.18.2.0/24 via 10.0.3.254; done
    $ for NODE in nodeC1 nodeC2; do sudo docker exec -it $NODE ip route add 192.168.4.0/24 via 10.0.3.254; done

    $ for NODE in nodeD1 nodeD2; do sudo docker exec -it $NODE ip route add 100.100.100.0/24 via 192.168.4.254; done
    $ for NODE in nodeD1 nodeD2; do sudo docker exec -it $NODE ip route add 110.110.110.0/24 via 192.168.4.254; done
    $ for NODE in nodeD1 nodeD2; do sudo docker exec -it $NODE ip route add 120.120.120.0/24 via 192.168.4.254; done
    $ for NODE in nodeD1 nodeD2; do sudo docker exec -it $NODE ip route add 130.130.130.0/24 via 192.168.4.254; done
    $ for NODE in nodeD1 nodeD2; do sudo docker exec -it $NODE ip route add 172.18.1.0/24 via 192.168.4.254; done
    $ for NODE in nodeD1 nodeD2; do sudo docker exec -it $NODE ip route add 172.18.2.0/24 via 192.168.4.254; done
    $ for NODE in nodeD1 nodeD2; do sudo docker exec -it $NODE ip route add 10.0.3.0/24 via 192.168.4.254; done

    $ sudo docker exec -it rt0 ip route add 10.0.3.0/24 via 100.100.100.2
    $ sudo docker exec -it rt0 ip route add 192.168.4.0/24 via 100.100.100.2
    $ sudo docker exec -it rt0 ip route add 110.110.110.0/24 via 100.100.100.2
    $ sudo docker exec -it rt0 ip route add 120.120.120.0/24 via 100.100.100.2
    $ sudo docker exec -it rt0 ip route add 130.130.130.0/24 via 100.100.100.2
    $ sudo docker exec -it rt0 ip route add 192.168.4.0/24 via 100.100.100.2
    $ sudo docker exec -it rt0 ip route add 10.0.3.0/24 via 100.100.100.2

    $ sudo docker exec -it rt1 ip route add 10.0.3.0/24 via 110.110.110.2
    $ sudo docker exec -it rt1 ip route add 192.168.4.0/24 via 110.110.110.2
    $ sudo docker exec -it rt1 ip route add 120.120.120.0/24 via 110.110.110.2
    $ sudo docker exec -it rt1 ip route add 130.130.130.0/24 via 110.110.110.2
    $ sudo docker exec -it rt1 ip route add 172.18.1.0/24 via 100.100.100.1
    $ sudo docker exec -it rt1 ip route add 172.18.2.0/24 via 100.100.100.1

    $ sudo docker exec -it rt2 ip route add 10.0.3.0/24 via 120.120.120.2
    $ sudo docker exec -it rt2 ip route add 192.168.4.0/24 via 130.130.130.2
    $ sudo docker exec -it rt2 ip route add 100.100.100.0/24 via 110.110.110.1
    $ sudo docker exec -it rt2 ip route add 172.18.1.0/24 via 110.110.110.1
    $ sudo docker exec -it rt2 ip route add 172.18.2.0/24 via 110.110.110.1

    $ sudo docker exec -it rt3 ip route add 192.168.4.0/24 via 120.120.120.1
    $ sudo docker exec -it rt3 ip route add 100.100.100.0/24 via 120.120.120.1
    $ sudo docker exec -it rt3 ip route add 110.110.110.0/24 via 120.120.120.1
    $ sudo docker exec -it rt3 ip route add 130.130.130.0/24 via 120.120.120.1
    $ sudo docker exec -it rt3 ip route add 172.18.1.0/24 via 120.120.120.1
    $ sudo docker exec -it rt3 ip route add 172.18.2.0/24 via 120.120.120.1

    $ sudo docker exec -it rt4 ip route add 10.0.3.0/24 via 130.130.130.1
    $ sudo docker exec -it rt4 ip route add 100.100.100.0/24 via 130.130.130.1
    $ sudo docker exec -it rt4 ip route add 110.110.110.0/24 via 130.130.130.1
    $ sudo docker exec -it rt4 ip route add 130.130.130.0/24 via 130.130.130.1
    $ sudo docker exec -it rt4 ip route add 172.18.1.0/24 via 130.130.130.1
    $ sudo docker exec -it rt4 ip route add 172.18.2.0/24 via 130.130.130.1


                                                                                                                         
![l3net](https://github.com/yuno-x/ctlvnet/raw/img/complex_net.png)

さて、上記を見るにスタティックルート情報の設定はネットワーク構成が少し複雑になるだけで、非常に面倒になることがわかります。
ただしエンドポイントのノードが上記のように1つのルータにしか接続されていない場合、全ての宛先(0.0.0.0/0)へのルート情報を設定することでエンドポイントのルーティング設定を簡易化できます。
例えば、

    $ for NODE in nodeA1 nodeA2 nodeA3; do sudo docker exec -it $NODE ip route add 100.100.100.0/24 via 172.18.1.254; done
    $ for NODE in nodeA1 nodeA2 nodeA3; do sudo docker exec -it $NODE ip route add 110.110.110.0/24 via 172.18.1.254; done
    $ for NODE in nodeA1 nodeA2 nodeA3; do sudo docker exec -it $NODE ip route add 120.120.120.0/24 via 172.18.1.254; done
    $ for NODE in nodeA1 nodeA2 nodeA3; do sudo docker exec -it $NODE ip route add 130.130.130.0/24 via 172.18.1.254; done
    $ for NODE in nodeA1 nodeA2 nodeA3; do sudo docker exec -it $NODE ip route add 10.0.3.0/24 via 172.18.1.254; done
    $ for NODE in nodeA1 nodeA2 nodeA3; do sudo docker exec -it $NODE ip route add 192.168.4.0/24 via 172.18.1.254; done

を、

    $ for NODE in nodeA1 nodeA2 nodeA3; do sudo docker exec -it $NODE ip route add default via 172.18.1.254; done

と置き換えることができます。この全ての宛先へのルートをデフォルトルートとよび、ネクストホップとなるルータをデフォルトゲートウェイとよびます。
ただし、エンドポイントにデフォルトルートを設定したところで、ルータのルーティング設定は煩雑なままとなっています。  
これを解決するためにダイナミックルーティングを使用することができます。  
その前に全ノードのルート情報を初期化しましょう。

    $ for NODE in $(sudo docker ps --format "{{.Names}}"); do sudo docker exec -it $NODE ip route flush scope global; done

これで手動で設定したルート情報が削除されたはずです。

さて、今のネットワーク構成は次のコマンドが実行されたときと同じ構成になっているはずです。
きちんとネットワークが構成されてる自信がない方は以下のコマンドを実行してください。

    $ ./rmcontainer.sh rt0 rt1 rt2 rt3 rt4 nodeA1 nodeA2 nodeA3 nodeB1 nodeB2 nodeC1 nodeC2 nodeD1 nodeD2
    $ ./ctl2net.sh delete brA brB brC brD

    $ ./mkcontainer.sh node rt0 rt1 rt2 rt3 rt4 nodeA1 nodeA2 nodeA3 nodeB1 nodeB2 nodeC1 nodeC2 nodeD1 nodeD2
    $ ./ctl2net.sh setup brA nodeA1 172.18.1.1/24 nodeA2 172.18.1.2/24 nodeA3 172.18.1.3/24 rt0 172.18.1.254/24
    $ ./ctl2net.sh setup brB nodeB1 172.18.2.1/24 nodeB2 172.18.2.2/24 rt0 172.18.2.254/24
    $ ./ctl2net.sh setup brC nodeC1 10.0.3.1/24 nodeC2 10.0.3.2/24 rt3 10.0.3.254/24
    $ ./ctl2net.sh setup brD nodeD1 192.168.4.1/24 nodeD2 192.168.4.2/24 rt4 192.168.4.254/24
    $ ./ctl2net.sh connect rt0 100.100.100.1/24 rt1 100.100.100.2/24
    $ ./ctl2net.sh connect rt1 110.110.110.1/24 rt2 110.110.110.2/24
    $ ./ctl2net.sh connect rt2 120.120.120.1/24 rt3 120.120.120.2/24
    $ ./ctl2net.sh connect rt2 130.130.130.1/24 rt4 130.130.130.2/24
                                                                                                               

これで確実に想定通りのネットワーク構成になっているはずです。
これでダイナミックルーティングの準備ができました。

### RIP (ダイナミックルーティング・プロトコル)

RIPは最もシンプルなルーティングプロトコルの一つです。
RIPを使用しているルータは自分が属しているセグメントを他のRIPを使用しているルータへ広告し、広告を受け取ったルータは自動的に適切なルート情報をルーティングテーブルへ追加します。
つまり、スタティックルーティングでは自分自身にルート情報を登録していたが、ダイナミックルーティングでは同じルーティングプロトコルを使用しているルータにルート情報を登録させます。  
今回のダイナミックルーティングを行うためにノードにFRRoutingというダイナミックルーティングを行うソフトウェアをインストールしています。
FRRoutingはCiscoルータライクのコマンドによって操作することができ、Ciscoルータを用いたネットワークの構築を練習することができます。

FRRoutingでルーティングの設定を行うにはいくつか方法がありますが、vtyshを使用するとCiscoルータのような操作が可能です。
以下ではルータrt0をRIPルータとして使用する上で、広告するセグメント情報の設定を行っています。

    [rt0]
    (rt0)# vtysh
    rt0# configure terminal
    rt0(config)# router rip
    rt0(config-router)# network 172.18.1.0/24
    rt0(config-router)# network 172.18.2.0/24
    rt0(config-router)# network 100.100.100.0/24
    rt0(config-router)# exit
    rt0(config)# exit
    rt0# exit

"rt0#"はvtyshのプロンプトで、Ciscoルータの特権EXECモードに相当するコマンドラインです。
ここで configure terminal コマンドを実行すればグローバルコンフィグレーションモード(プロンプト: "rt0(config)#")に遷移できます。
このモードで一般的な設定を行います。
RIPルータを有効にし、当該ルータを設定するモードであるルーティングプロトコルコンフィグレーションモード(プロンプト: "rt0(config-router)#")に遷移します。
ここでnetworkコマンドでrt0が属している広告したいセグメント情報を設定します。
rt0は172.18.1.0/24, 172.18.2.0/24, 100.100.100.0/24に属しており、何も考えずとりあえずこれら全てのセグメントを広告しましょう。
このようにすると、他のRIPルータへルート情報を配布します。

それでは他のルータもRIPの設定をしましょう。

    [rt1]
    (rt1)# vtysh
    rt1# configure terminal 
    rt1(config)# router rip
    rt1(config-router)# network 100.100.100.0/24
    rt1(config-router)# network 110.110.110.0/24
    rt1(config-router)# exit
    rt1(config)# exit
    rt1# exit

    [rt2]
    (rt2)# vtysh
    rt2# configure terminal 
    rt2(config)# router rip
    rt2(config-router)# network 110.110.110.0/24
    rt2(config-router)# network 120.120.120.0/24
    rt2(config-router)# network 130.130.130.0/24
    rt2(config-router)# exit
    rt2(config)# exit
    rt2# exit

    [rt3]
    (rt3)# vtysh
    rt3# configure terminal 
    rt3(config)# router rip
    rt3(config-router)# network 120.120.120.0/24
    rt3(config-router)# network 10.0.3.0/24
    rt3(config-router)# exit
    rt3(config)# exit
    rt3# exit

    [rt4]
    (rt4)# vtysh
    rt4# configure terminal 
    rt4(config)# router rip
    rt4(config-router)# network 130.130.130.0/24
    rt4(config-router)# network 192.168.4.0/24
    rt4(config-router)# exit
    rt4(config)# exit
    rt4# exit

さて、各ルータに全てのルート情報を登録するよりもずっとシンプルで分かりやすいと思います。
これがダイナミックルーティングの真骨頂です。 
さて、このままではまだnodeA1からnodeC1やnodeD1へpingを送れません。
そこで、各セグメントのルータにデフォルトゲートウェイを設定しましょう。

    $ for NODE in nodeA1 nodeA2 nodeA3; do sudo docker exec -it $NODE ip route add default via 172.18.1.254; done
    $ for NODE in nodeB1 nodeB2; do sudo docker exec -it $NODE ip route add default via 172.18.2.254; done
    $ for NODE in nodeC1 nodeC2; do sudo docker exec -it $NODE ip route add default via 10.0.3.254; done
    $ for NODE in nodeD1 nodeD2; do sudo docker exec -it $NODE ip route add default via 192.168.4.254; done

これで任意のセグメントのノードから、異なるセグメントのノードへpingを送ることができます。
pingを送るときはIPアドレスを指定するのもいいですが、
mDNSを使用して、例えばnodeD2にpingを送るとしたらpingコマンドの引数にnodeD2.localを指定してもpingを送れます。
ただし、mDNSを利用するときは名前解決に少しだけ時間が掛かってしまうのでpingの-nオプションで名前解決を行わないようにしましょう。

    [nodeA1]
    (nodeA1)# ping -n nodeD2.lcoal

このようにIPアドレスとmDNSのどちらかお好きな方を使用できます。

また、tracerouteコマンドで目的のノードへの通信で経由したルートを表示することができます。
tracerouteでも同様に-nオプションで名前解決を行わないようにできます。

    [nodeA1]
    (nodeA1)# traceroute -n nodeD2.local
    traceroute to nodeD2.local (192.168.4.2), 30 hops max, 60 byte packets
     1  172.18.1.254  0.881 ms  0.814 ms  0.779 ms
     2  100.100.100.2  0.749 ms  0.699 ms  0.661 ms
     3  110.110.110.2  0.623 ms  0.572 ms  0.532 ms
     4  130.130.130.2  0.493 ms  0.439 ms  0.392 ms
     5  192.168.4.2  0.348 ms  0.282 ms  0.226 ms

ここでip routeコマンドでルータのルーティングテーブルを確認してみましょう。
例えばrt1のルーティングテーブルは次のようになっているはずです。

    (rt1)# ip route
    10.0.3.0/24 via 110.110.110.2 dev veth1 proto zebra metric 20 
    100.100.100.0/24 dev veth0 proto kernel scope link src 100.100.100.2 
    110.110.110.0/24 dev veth1 proto kernel scope link src 110.110.110.1 
    120.120.120.0/24 via 110.110.110.2 dev veth1 proto zebra metric 20 
    130.130.130.0/24 via 110.110.110.2 dev veth1 proto zebra metric 20 
    172.18.1.0/24 via 100.100.100.1 dev veth0 proto zebra metric 20 
    172.18.2.0/24 via 100.100.100.1 dev veth0 proto zebra metric 20 
    192.168.4.0/24 via 110.110.110.2 dev veth1 proto zebra metric 20

proto zebraの文字列が含まれているルート情報がFRRoutingによって登録されたルートです。
172.18.1.0/24, 172.18.2.0/24がrt0から、120.120.120.0/24, 130.130.130.0/24, 10.0.3.0/24, 192.168.4.0/24がrt2から広告されたものであることが分かります。

以上でRIPルータの設定の仕方が分かったと思いますが、RIPは前述した通り、最もシンプルなルーティングプロトコルの一つとなっており、
収束（ルート情報の適用のスピード）が遅いことや、ホップ数に大きな制限があること、冗長構成でのブロードキャストストームへ対応できないことが欠点となっています。
これを解決してくれるのがOSPFです。
OSPFを設定する前に各ルータのRIP機能を停止しておきましょう。

    [rt0]
    (rt0)# vtysh
    rt0# configure terminal 
    rt0(config)# no router rip
    rt0(config)# exit
    rt0# exit

    [rt1]
    (rt1)# vtysh
    rt1# configure terminal 
    rt1(config)# no router rip
    rt1(config)# exit
    rt1# exit

    [rt2]
    (rt2)# vtysh
    rt2# configure terminal 
    rt2(config)# no router rip
    rt2(config)# exit
    rt2# exit

    [rt3]
    (rt3)# vtysh
    rt3# configure terminal 
    rt3(config)# no router rip
    rt3(config)# exit
    rt3# exit

    [rt4]
    (rt4)# vtysh
    rt4# configure terminal 
    rt4(config)# no router rip
    rt4(config)# exit
    rt4# exit

これでRIPのルーティングは停止します。


### OSPF (ダイナミックルーティング・プロトコル)

OSPFによるルーティングを行うには以下の設定をします。

    [rt0]
    (rt0)# vtysh
    rt0# configure terminal
    rt0(config)# router ospf
    rt0(config-router)# network 172.18.1.0/24 area 0
    rt0(config-router)# network 172.18.2.0/24 area 0
    rt0(config-router)# network 100.100.100.0/24 area 0
    rt0(config-router)# exit
    rt0(config)# exit
    rt0# exit
   
    [rt1]
    (rt1)# vtysh
    rt1# configure terminal
    rt1(config)# router ospf
    rt1(config-router)# network 100.100.100.0/24 area 0
    rt1(config-router)# network 110.110.110.0/24 area 0
    rt1(config-router)# exit
    rt1(config)# exit
    rt1# exit

    [rt2]
    (rt2)# vtysh
    rt2# configure terminal
    rt2(config)# router ospf
    rt2(config-router)# network 110.110.110.0/24 area 0
    rt2(config-router)# network 120.120.120.0/24 area 0
    rt2(config-router)# network 130.130.130.0/24 area 0
    rt2(config-router)# exit
    rt2(config)# exit
    rt2# exit

    [rt3]
    (rt3)# vtysh
    rt3# configure terminal
    rt3(config)# router ospf
    rt3(config-router)# network 120.120.120.0/24 area 0
    rt3(config-router)# network 10.0.3.0/24 area 0
    rt3(config-router)# exit
    rt3(config)# exit
    rt3# exit

    [rt4]
    (rt4)# vtysh
    rt4# configure terminal
    rt4(config)# router ospf
    rt4(config-router)# network 130.130.130.0/24 area 0
    rt4(config-router)# network 192.168.4.0/24 area 0
    rt4(config-router)# exit
    rt4(config)# exit
    rt4# exit

Ciscoルータとは若干コマンドは異なりますが、大方は同じです。
これにより異なるセグメントのノード同士で通信ができることを確認することができます。

企業内など統一された運用ポリシーで管理されたネットワーク、つまりAS(Autonomous System)内では
RIPよりもOSPFを利用することが多いです。
ただし、AS間ではRIPやOSPFといったいわゆるIGPは使用されず、
EGPの一つであるBGPというルーティングプロトコルが使われていることが多いです。  
OSPFの設定をクリアするためには以下のコマンドを実行します。

    [rt0]
    (rt0)# vtysh
    rt0# configure terminal 
    rt0(config)# no router ospf
    rt0(config)# exit
    rt0# exit

    [rt1]
    (rt1)# vtysh
    rt1# configure terminal 
    rt1(config)# no router ospf
    rt1(config)# exit
    rt1# exit

    [rt2]
    (rt2)# vtysh
    rt2# configure terminal 
    rt2(config)# no router ospf
    rt2(config)# exit
    rt2# exit

    [rt3]
    (rt3)# vtysh
    rt3# configure terminal 
    rt3(config)# no router ospf
    rt3(config)# exit
    rt3# exit

    [rt4]
    (rt4)# vtysh
    rt4# configure terminal 
    rt4(config)# no router ospf
    rt4(config)# exit
    rt4# exit

これでOSPFのルーティングは停止します。


### BGP (ダイナミックルーティング・プロトコル)

次のネットワークを3つのASに分けます。IGPとしてOSPFを利用しています。

![l3net](https://github.com/yuno-x/ctlvnet/raw/img/bgp.png)

AS間でルーティングするには対向のASのEGPルーティングを行うルータと接続設定しなければいけません。
そのため、BGPのようなEGPではネイバーを指定します。

BGPによるルーティングを行うには以下の設定をします。

    [rt0]
    (rt0)# vtysh
    rt0# configure terminal
    rt0(config)# router bgp 100
    rt0(config-router)# neighbor 100.100.100.2 remote-as 200
    rt0(config-router)# network 172.18.1.0 mask 255.255.255.0
    rt0(config-router)# network 172.18.2.0 mask 255.255.255.0
    rt0(config-router)# exit
    rt0(config)# exit
    rt0# exit
   
    [rt1]
    (rt1)# vtysh
    rt1# configure terminal
    rt1(config)# router bgp 200
    rt1(config-router)# neighbor 100.100.100.1 remote-as 100
    rt1(config-router)# neighbor 110.110.110.2 remote-as 300
    rt1(config-router)# exit
    rt1(config)# exit
    rt1# exit

    [rt2]
    (rt2)# vtysh
    rt2# configure terminal
    rt2(config)# router bgp 300
    rt2(config-router)# neighbor 110.110.110.1 remote-as 200
    rt2(config-router)# network 10.0.3.0 mask 255.255.255.0
    rt2(config-router)# network 192.168.4.0 mask 255.255.255.0
    rt2(config-router)# exit
    rt2(config)# router ospf
    rt2(config-router)# redistribute bgp
    rt2(config-router)# network 120.120.120.0/24 area 0
    rt2(config-router)# network 130.130.130.0/24 area 0
    rt2(config-router)# exit
    rt2(config)# exit
    rt2# exit

    [rt3]
    (rt3)# vtysh
    rt3# configure terminal
    rt3(config)# router ospf
    rt3(config-router)# network 120.120.120.0/24 area 0
    rt3(config-router)# network 10.0.3.0/24 area 0
    rt3(config-router)# exit
    rt3(config)# exit
    rt3# exit

    [rt4]
    (rt4)# vtysh
    rt4# configure terminal
    rt4(config)# router ospf
    rt4(config-router)# network 130.130.130.0/24 area 0
    rt4(config-router)# network 192.168.4.0/24 area 0
    rt4(config-router)# exit
    rt4(config)# exit
    rt4# exit

今回はAS番号を100, 200, 300に分けました。
BGPネイバーとしてIPアドレスとAS番号を指定し、そのBGPネイバーに渡したいルート情報を設定しています。
ただし、rt2ではOSPFで広告したいルート情報にBGPで取得したルート情報を加えるために再配布の設定を行っています。
これを行わないと普通、OSPFではOSPFルータが属しているネットワークの情報しか広告できず、
rt3とrt4とそれらの配下がAS外部と通信できないことになります。

このネットワークではAS内のネットワークが単純なのでAS内のネットワーク情報を外部に広告するのもそこまで大変ではありませんが、
AS内のネットワークが変更になったときや複雑になったときに、AS内のネットワーク情報を外部に広告する設定の手間を軽くしたいです。
そのようなときは今度はBGPで他のプロトコルで取得したルート情報を再配布すれば良いです。

次はAS内部のネットワーク情報をBGPで再配布するときの設定です。
まず、手動で設定したBGPで広告するネットワーク情報をクリアします。
その後、ルータが属しているネットワーク情報や、OSPFで取得したルート情報を再配布するように設定をします。

    [rt0]
    (rt0)# vtysh
    rt0# configure terminal
    rt0(config)# router bgp 100
    rt0(config-router)# no network 172.18.1.0 mask 255.255.255.0
    rt0(config-router)# no network 172.18.2.0 mask 255.255.255.0
    rt0(config-router)# redistribute connected
    rt0(config-router)# exit
    rt0(config)# exit
    rt0# exit
   
    [rt2]
    (rt2)# vtysh
    rt2# configure terminal
    rt2(config)# router bgp 300
    rt2(config-router)# no network 10.0.3.0 mask 255.255.255.0
    rt2(config-router)# no network 192.168.4.0 mask 255.255.255.0
    rt2(config-router)# redistribute ospf
    rt2(config-router)# exit
    rt2(config)# exit
    rt2# exit

これでBGPで広告するネットワーク情報を手動で設定する必要がなくなりました。
pingなどで通信が疎通していることを確認してみてください。


### まとめ
さて、本ドキュメントでは静的ルーティングと動的ルーティングであるRIP、OSPF、BGPの設定例を示しました。
しかし、もちろんもっと大きなネットワークを構成することができますし、FRRoutingにはさらに多くの機能があるため色々試してみると勉強になると思います。

以上が本ツールの使い方となります。
