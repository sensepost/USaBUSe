package com.sensepost.hidproxy;

import java.io.File;
import java.io.IOException;
import java.net.InetSocketAddress;
import java.net.SocketAddress;
import java.net.SocketException;

import io.netty.bootstrap.Bootstrap;
import io.netty.bootstrap.ServerBootstrap;
import io.netty.buffer.ByteBuf;
import io.netty.channel.Channel;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelFutureListener;
import io.netty.channel.ChannelHandlerAdapter;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelInitializer;
import io.netty.channel.ChannelOption;
import io.netty.channel.ChannelPromise;
import io.netty.channel.EventLoopGroup;
import io.netty.channel.FixedRecvByteBufAllocator;
import io.netty.channel.RecvByteBufAllocator;
import io.netty.channel.nio.NioEventLoopGroup;
import io.netty.channel.oio.OioEventLoopGroup;
import io.netty.channel.socket.nio.NioServerSocketChannel;
import io.netty.channel.socket.nio.NioSocketChannel;

public class Main {

	static final String SOURCE = System.getProperty("source", "0.0.0.0:65534");
	static final String PAYLOAD0 = System.getProperty("payload", "../powershell/Proxy.ps1");
	static final String TARGET = System.getProperty("target", "localhost:4444,localhost:65535");
	static final int PACKETSIZE = Integer.parseInt(System.getProperty("packetsize", "64"));

	private static InetSocketAddress[] parseTargets(String param) {
		String[] split = param.split(",");
		InetSocketAddress[] targets = new InetSocketAddress[split.length];
		for (int i=0; i<split.length; i++) {
			int colon = split[i].indexOf(':');
			targets[i] = new InetSocketAddress(split[i].substring(0, colon),
					Integer.parseInt(split[i].substring(colon + 1)));
		}
		return targets;
	}

	private static String toString(InetSocketAddress[] targets) {
		StringBuilder b = new StringBuilder();
		if (targets.length >= 1) {
			b.append(targets[0]);
			for (int i=1; i<targets.length; i++) {
				b.append(",").append(targets[i]);
			}
		} else {
			b.append("None!");
		}
		return b.toString();
	}

	public static void main(String[] args) throws Exception {

		File payload0 = new File(PAYLOAD0);
		if (!payload0.canRead()) {
			System.err.println("Cannot read " + payload0);
			System.exit(0);
		}

		SocketAddress source;
		EventLoopGroup bossGroup, workerGroup;
		Channel c;

		InetSocketAddress[] targets = parseTargets(TARGET);

		int colon = SOURCE.indexOf(':');
		if (colon > -1) {
			source = new InetSocketAddress(SOURCE.substring(0, colon), Integer.parseInt(SOURCE.substring(colon + 1)));
			bossGroup = new NioEventLoopGroup(1);
			workerGroup = new NioEventLoopGroup();
			try {
				ServerBootstrap b = new ServerBootstrap();
				b.group(bossGroup, workerGroup).channel(NioServerSocketChannel.class)
						.childHandler(new MuxInitializer(targets, payload0, PACKETSIZE));
				c = b.bind(source).sync().channel();

				System.out.println("Listening on " + source + "\n" + "Connections will be relayed to " + toString(targets)
						+ "\nPress Enter to shutdown");
				System.in.read();
				System.out.print("Exiting...");
				ChannelFuture f = c.closeFuture();
				c.close();
				f.sync();
				System.out.println("Done");
			} finally {
				bossGroup.shutdownGracefully();
				workerGroup.shutdownGracefully();
			}

		} else {
			File s = new File(SOURCE);
			if (s.exists() && s.canRead() && s.canWrite()) {
				source = new FileAddress(s);
				bossGroup = new OioEventLoopGroup(1);
				try {
					Bootstrap b = new Bootstrap();
					b.group(bossGroup).channel(FileChannel.class)
							.handler(new MuxInitializer(targets, payload0, PACKETSIZE));
					c = b.connect(source).sync().channel();
					System.out.println("Listening on " + source + "\n" + "Connections will be relayed to " + targets
							+ "\nPress Enter to shutdown");
					System.in.read();
					System.out.print("Exiting...");
					ChannelFuture f = c.closeFuture();
					c.close();
					f.sync();
					System.out.println("Done");
				} finally {
					bossGroup.shutdownGracefully();
				}
			} else
				throw new IllegalArgumentException(
						"Cannot use " + SOURCE + " as the source, file not found or permissions incorrect");
		}
	}

	private static class MuxInitializer extends ChannelInitializer<Channel> {

		private InetSocketAddress[] targets;
		private File payload0;
		private int packetSize;

		public MuxInitializer(InetSocketAddress[] targets, File payload0, int packetSize) {
			this.targets = targets;
			this.payload0 = payload0;
			this.packetSize = packetSize;
		}

		@Override
		public void channelActive(ChannelHandlerContext ctx) throws Exception {
			System.err.println("Channel active!");
			super.channelActive(ctx);
		}

		@Override
		public void initChannel(Channel ch) throws Exception {
			ch.pipeline().addLast(new PacketCodec(packetSize), new MuxHandler(targets, payload0));
		}
	}

	public static final class MuxHandler extends ChannelHandlerAdapter {
		private InetSocketAddress[] targets;

		private File payload0;

		private Channel[] conns = new Channel[256];

		private RecvByteBufAllocator allocator = new FixedRecvByteBufAllocator(60);

		public MuxHandler(InetSocketAddress[] targets, File payload0) {
			this.targets = targets;
			this.payload0 = payload0;
		}

		@Override
		public void channelActive(ChannelHandlerContext ctx) throws Exception {
			System.err.println("Connection received from " + ctx.channel().remoteAddress());
		}

		@Override
		public void channelInactive(ChannelHandlerContext ctx) throws Exception {
			System.err.println("Connection from " + ctx.channel().remoteAddress() + " closed!");
			for (int i = 0; i < conns.length; i++) {
				if (conns[i] != null) {
					conns[i].close();
					conns[i] = null;
				}
			}
		}

		@Override
		public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
			if (cause instanceof IOException) {
				System.err.println("Network connection closed!");
			} else
				super.exceptionCaught(ctx, cause);
		}

		@Override
		public void close(ChannelHandlerContext ctx, ChannelPromise promise) throws Exception {
			// TODO Auto-generated method stub
			super.close(ctx, promise);
		}

		private Packet makeResetPacket(Packet p) {
			Packet response = new Packet();
			response.setFlags(Packet.RST | Packet.ACK);
			response.setChannel(p.getChannel());
			response.setAck(p.getSeq() + 1);
			return response;
		}

		@Override
		public void channelRead(final ChannelHandlerContext ctx, Object msg) {
			if (!(msg instanceof Packet)) {
				System.err.println("Unexpected object received: " + msg);
				return;
			}
			final Packet p = (Packet) msg;
			final int c = p.getChannel();

			if (p.getFlags() == Packet.SYN) {
				if (conns[c] != null) { // SYN on existing channel!
					// For the moment, let's discard the existing state
					conns[c].close();
				}
				ChannelFuture f;
				Bootstrap b = new Bootstrap().handler(new HIDProxyBackendInitializer(ctx.channel(), c, allocator))
						.option(ChannelOption.AUTO_READ, false);
				if (c == 0) {
					System.out.println("Connecting Channel 0 to the secondary payload");
					b.group(new OioEventLoopGroup()).channel(ChunkedFileChannel.class);
					FileAddress fa = new FileAddress(payload0);
					f = b.connect(fa);
				} else {
					InetSocketAddress target = c > targets.length ? targets[targets.length - 1] : targets[c - 1];
					System.out.println(String.format("Connecting Channel %d to %s", c, target.toString()));
					// Start the connection attempt.
					b.group(ctx.channel().eventLoop()).channel(NioSocketChannel.class);
					f = b.connect(target);
				}
				f.addListener(new ChannelFutureListener() {
					@Override
					public void operationComplete(ChannelFuture future) {
						if (future.isSuccess()) {
							conns[c] = future.channel();
							future.channel().writeAndFlush(p);
						} else {
							conns[c] = null;
							future.cause().printStackTrace();
							// Close the connection if the connection
							// attempt has failed.
							ctx.channel().writeAndFlush(makeResetPacket(p));
						}
					}
				});
			} else if (conns[c] != null) {
				conns[c].writeAndFlush(p);
			}
		}

		@Override
		public void write(ChannelHandlerContext ctx, Object msg, ChannelPromise promise) throws Exception {
			super.write(ctx, msg, promise);
		}
	}

	private static class HIDProxyBackendInitializer extends ChannelInitializer<Channel> {
		private Channel inboundChannel;
		private int channel;
		private RecvByteBufAllocator allocator;

		public HIDProxyBackendInitializer(Channel inboundChannel, int channel, RecvByteBufAllocator allocator) {
			this.inboundChannel = inboundChannel;
			this.channel = channel;
			this.allocator = allocator;
		}

		@Override
		protected void initChannel(Channel ch) throws Exception {
			ch.config().setRecvByteBufAllocator(allocator);
			ch.pipeline().addLast(/*new ChunkedFrameDecoder(60),*/ new TCPCodec(inboundChannel, channel));
		}

	}

	public static class ChunkedFileChannel extends FileChannel {

		@Override
		public int available() {
			try {
				return Math.min(fis.available(), 60);
			} catch (IOException ignore) {
				return 0;
			}
		}

	}

}
