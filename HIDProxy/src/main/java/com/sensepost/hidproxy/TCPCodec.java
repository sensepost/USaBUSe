package com.sensepost.hidproxy;

import io.netty.buffer.ByteBuf;
import io.netty.buffer.Unpooled;
import io.netty.channel.Channel;
import io.netty.channel.ChannelHandlerAdapter;
import io.netty.channel.ChannelHandlerContext;
import io.netty.channel.ChannelPromise;

public class TCPCodec extends ChannelHandlerAdapter {
	private Channel inbound;
	private int channel, rcvSeq = 0;
	private volatile int sendSeq = 0;

	public TCPCodec(Channel inbound, int channel) {
		this.inbound = inbound;
		this.channel = channel;
	}

	@Override
	public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
		if (!(msg instanceof ByteBuf)) {
			System.err.println("Unexpected object: " + msg);
			return;
		}
		ByteBuf buf = (ByteBuf) msg;

		while (buf.readableBytes() > 0) {
			byte[] data = new byte[Math.min(60, buf.readableBytes())];
			buf.readBytes(data);
			Packet p = makePacket(Packet.ACK, data, data.length);
			inbound.writeAndFlush(p);
		}
		buf.release();
	}


	@Override
	public void channelReadComplete(ChannelHandlerContext ctx) throws Exception {
		// This helps to ensure that packets are only sent after each ack
		// for channel 0. If we allow repeated reads, there will be more than one
		// packet in flight at a time, which can overrun the naive loader.
//		if (channel != 0)
//			super.channelReadComplete(ctx);
	}

	private Packet makePacket(int flags, byte[] data, int length) {
		if ((flags & Packet.SYN) == Packet.SYN || (flags & Packet.FIN) == Packet.FIN || length > 0)
			sendSeq++;

		Packet p = new Packet();
		p.setChannel(channel);
		p.setFlags(flags);
		p.setSeq(sendSeq);
		p.setAck(rcvSeq + 1);
		p.setData(data, 0, length);
		return p;
	}

	@Override
	public void channelInactive(ChannelHandlerContext ctx) throws Exception {
		inbound.writeAndFlush(makePacket(Packet.FIN, null, 0));
		super.channelInactive(ctx);
	}

	@Override
	public void write(ChannelHandlerContext ctx, Object msg, ChannelPromise promise) throws Exception {
		if (!(msg instanceof Packet)) {
			System.err.println("Unexpected object: " + msg);
			return;
		}
		Packet p = (Packet) msg;
		int flags = p.getFlags();
		if (flags == Packet.SYN) {
			rcvSeq = p.getSeq();
			inbound.writeAndFlush(makePacket(Packet.SYN | Packet.ACK, null, 0));
			return;
		} else if (flags == (Packet.SYN | Packet.ACK)) {
			// response to us sending a SYN, not implemented yet // FIXME
		} else if (flags == Packet.ACK) {
			// only once the SYN/ACK is complete
//			if (channel != 0) {
//				// only for channels speaking to the more capable
//				// secondary implementation
//				ctx.channel().config().setAutoRead(true);
//			}
			ctx.read();

			if (p.getSeq() == (rcvSeq & 0xF)) {
				// no data
			} else if (p.getSeq() == ((rcvSeq + 1) & 0xF)) {
				rcvSeq++;
				byte[] data = p.getData();
				if (data.length > 0) {
					super.write(ctx, Unpooled.wrappedBuffer(data), promise);
				}
				inbound.writeAndFlush(makePacket(Packet.ACK, null, 0));
			} else {
				System.err.println("Received packet out of order!\n" + this + "\n" + p);
				inbound.writeAndFlush(makePacket(Packet.RST, null, 0));
			}
		} else if (flags == Packet.FIN) {
			if (p.getSeq() == ((rcvSeq + 1) & 0xF)) {
				rcvSeq++;
				inbound.writeAndFlush(makePacket(Packet.FIN | Packet.ACK, null, 0));
				ctx.close();
			} else {
				System.err.println("Received packet out of order!\n" + this + "\n" + p);
				inbound.writeAndFlush(makePacket(Packet.RST, null, 0));
			}
		}
	}

	@Override
	public void exceptionCaught(ChannelHandlerContext ctx, Throwable cause) throws Exception {
		inbound.writeAndFlush(makePacket(Packet.RST, null, 0));
		super.exceptionCaught(ctx, cause);
	}

	@Override
	public void close(ChannelHandlerContext ctx, ChannelPromise promise) throws Exception {
		System.out.println("Channel " + channel + " closed!");
		super.close(ctx, promise);
	}

}