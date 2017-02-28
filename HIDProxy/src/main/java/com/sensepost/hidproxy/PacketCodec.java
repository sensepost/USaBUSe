package com.sensepost.hidproxy;

import java.util.List;

import io.netty.buffer.ByteBuf;
import io.netty.channel.ChannelHandlerContext;
import io.netty.handler.codec.ByteToMessageCodec;

public class PacketCodec extends ByteToMessageCodec<Packet> {
	/**
	 * Reads bytes from the multiplexed channel, and decodes them into
	 * Packets (adjusting for the case where we are connected directly via a
	 * network socket and receiving 65 bytes, vs connected via the HID, and
	 * only receiving 64-byte packets)
	 *
	 * Any Packets written to the multiplexed channel are similarly
	 * adjusted, by prefixing the packet with the reportID as necessary when
	 * converting to a byte array.
	 */
	private int size;

	public PacketCodec(int size) {
		this.size = size;
	}

	@Override
	protected void decode(ChannelHandlerContext ctx, ByteBuf in, List<Object> out) {
		if (in.readableBytes() < size) {
			return;
		}
		byte[] buff = new byte[size];
		in.readBytes(buff);
		if (size > 64) {
			System.arraycopy(buff, size - 64, buff, 0, 64);
		}
		out.add(new Packet(buff));
	}

	@Override
	protected void encode(ChannelHandlerContext ctx, Packet packet, ByteBuf buf) throws Exception {
		byte[] b = packet.getBytes();
		if (b.length < size) {
			byte[] t = new byte[size];
			System.arraycopy(b, 0, t, size - 64, 64);
			b = t;
		}
		buf.writeBytes(b);
	}
}