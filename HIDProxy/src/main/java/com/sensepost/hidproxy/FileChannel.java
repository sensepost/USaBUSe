package com.sensepost.hidproxy;

import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.net.SocketAddress;

import io.netty.channel.ChannelConfig;
import io.netty.channel.ChannelPromise;
import io.netty.channel.DefaultChannelConfig;
import io.netty.channel.oio.OioByteStreamChannel;

public class FileChannel extends OioByteStreamChannel {

	private boolean open = true;
	private ChannelConfig config;
	private FileAddress remote;
	private FileInputStream fis;
	private FileOutputStream fos;

	public FileChannel() {
		super(null);
		config = new DefaultChannelConfig(this);
	}

	@Override
	public ChannelConfig config() {
		return config;
	}

	@Override
	public boolean isOpen() {
		return open;
	}

	@Override
	protected AbstractUnsafe newUnsafe() {
		return new FileChannelUnsafe();
	}

	@Override
	protected void doConnect(SocketAddress remoteAddress, SocketAddress localAddress) throws Exception {
		remote = (FileAddress) remoteAddress;
	}

	protected void doInit() throws Exception {
		if (!remote.file().exists())
			throw new FileNotFoundException("File not found: " + remote.file());
		activate(fis = new FileInputStream(remote.file()), fos = new FileOutputStream(remote.file(), true));
	}

	@Override
	protected void doDisconnect() throws Exception {
		doClose();
	}

	@Override
	protected void doClose() throws Exception {
		open = false;
		try {
			super.doClose();
		} finally {
			try {
				fis.close();
			} catch (Exception e) {
			}
			try {
				fos.close();
			} catch (Exception e) {
			}
		}
	}

	private class FileChannelUnsafe extends AbstractUnsafe {
		@Override
		public void connect(final SocketAddress remoteAddress, final SocketAddress localAddress,
				final ChannelPromise promise) {
			if (!promise.setUncancellable() || !ensureOpen(promise)) {
				return;
			}

			try {
				final boolean wasActive = isActive();
				doConnect(remoteAddress, localAddress);

				doInit();
				safeSetSuccess(promise);
				if (!wasActive && isActive()) {
					pipeline().fireChannelActive();
				}
			} catch (Throwable t) {
				safeSetFailure(promise, t);
				closeIfClosed();
			}
		}
	}

	@Override
	protected void doBind(SocketAddress addr) throws Exception {
		throw new UnsupportedOperationException();

	}

	@Override
	protected SocketAddress localAddress0() {
		return remote;
	}

	@Override
	protected SocketAddress remoteAddress0() {
		return remote;
	}
}